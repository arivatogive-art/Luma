import {getMessaging} from "firebase-admin/messaging";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

const db = getFirestore();

const usersCollection = "users";
const conversationsCollection = "conversations";
const messagesCollection = "messages";
const notificationsCollection = "notifications";
const notificationTokensCollection = "notification_tokens";

const maxNotificationTokensPerUser = 500;
const fcmBatchSize = 500;

type UnknownRecord = Record<string, unknown>;

type NotificationTokenDocument = {
  token?: unknown;
  userId?: unknown;
  platform?: unknown;
  isWeb?: unknown;
};

type ConversationDocument = {
  participantIds?: unknown;
  participants?: unknown;
  mutedUserIds?: unknown;
  deletedForUserIds?: unknown;
  conversationType?: unknown;
  pageId?: unknown;
  pageName?: unknown;
  pageUsername?: unknown;
  pageAvatarUrl?: unknown;
  pageOwnerUserId?: unknown;
  pageTeamUserIds?: unknown;
  pageMessagingMode?: unknown;
  pageIsBlueVerified?: unknown;
  pageIsGreyVerified?: unknown;
};

type MessageDocument = {
  chatId?: unknown;
  senderUserId?: unknown;
  text?: unknown;
  messageType?: unknown;
  imageUrl?: unknown;
  createdAt?: unknown;
};

type ParticipantPreview = {
  userId: string;
  displayName: string;
  username: string;
  avatarUrl: string;
};

type NotificationSettings = {
  pushNotificationsEnabled: boolean;
  messageNotificationsEnabled: boolean;
  activityNotificationsEnabled: boolean;
  storyNotificationsEnabled: boolean;
  friendRequestNotificationsEnabled: boolean;
};

export const createMessengerNotificationOnNewMessage =
  onDocumentCreated(
    {
      document:
        `${conversationsCollection}/{conversationId}/` +
        `${messagesCollection}/{messageId}`,
      region: "europe-west3",
      maxInstances: 10,
    },
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        logger.warn(
          "Messenger push skipped: missing message snapshot.",
        );
        return;
      }

      const conversationId =
        cleanString(event.params.conversationId);
      const messageId =
        cleanString(event.params.messageId);
      const message =
        snapshot.data() as MessageDocument;

      const senderUserId =
        cleanString(message.senderUserId);
      const messageChatId =
        cleanString(message.chatId);

      if (!conversationId || !messageId || !senderUserId) {
        logger.warn(
          "Messenger push skipped: invalid identifiers.",
          {
            conversationId,
            messageId,
            senderUserId,
          },
        );
        return;
      }

      if (messageChatId && messageChatId !== conversationId) {
        logger.warn(
          "Messenger push skipped: chatId mismatch.",
          {
            conversationId,
            messageId,
            messageChatId,
          },
        );
        return;
      }

      const conversationSnapshot = await db
        .collection(conversationsCollection)
        .doc(conversationId)
        .get();

      if (!conversationSnapshot.exists) {
        logger.warn(
          "Messenger push skipped: conversation missing.",
          {
            conversationId,
            messageId,
          },
        );
        return;
      }

      const conversation =
        conversationSnapshot.data() as ConversationDocument;

      const participantIds =
        readStringArray(conversation.participantIds);

      if (
        participantIds.length < 2 ||
        !participantIds.includes(senderUserId)
      ) {
        logger.warn(
          "Messenger push skipped: invalid participants.",
          {
            conversationId,
            messageId,
            senderUserId,
            participantIds,
          },
        );
        return;
      }

      const mutedUserIds =
        new Set(readStringArray(conversation.mutedUserIds));

      const deletedForUserIds =
        new Set(readStringArray(conversation.deletedForUserIds));

      const conversationSenderPreview =
        findParticipantPreview(
          conversation.participants,
          senderUserId,
        );

      const senderProfile = await loadSenderIdentity({
        senderUserId,
        conversation,
        conversationFallback: conversationSenderPreview,
      });

      const recipients = participantIds.filter(
        (participantId) => {
          if (!participantId) return false;
          if (participantId === senderUserId) return false;
          if (mutedUserIds.has(participantId)) return false;
          if (deletedForUserIds.has(participantId)) return false;
          return true;
        },
      );

      if (recipients.length === 0) {
        return;
      }

      const title =
        senderProfile.displayName || "Neue Nachricht";
      const body =
        messengerNotificationBody(message);

      await Promise.all(
        recipients.map(async (recipientUserId) => {
          const settings =
            await loadUserNotificationSettings(recipientUserId);

          if (
            !settings.pushNotificationsEnabled ||
            !settings.messageNotificationsEnabled
          ) {
            logger.info(
              "Messenger push skipped by settings.",
              {
                recipientUserId,
                conversationId,
                messageId,
              },
            );
            return;
          }

          const tokens =
            await loadNotificationTokens(recipientUserId);

          if (tokens.length === 0) {
            logger.info(
              "Messenger push skipped: no registered tokens.",
              {
                recipientUserId,
                conversationId,
                messageId,
              },
            );
            return;
          }

          const notificationId =
            `direct_message_${messageId}`;

          const data: Record<string, string> = {
            notificationId,
            recipientUserId,
            type: "directMessage",
            targetType: "chat",
            referenceId: conversationId,
            targetId: conversationId,
            secondaryReferenceId: messageId,
            conversationId,
            chatId: conversationId,
            messageId,
            actorUserId: senderUserId,
            profileId:
              cleanString(conversation.pageId) || senderUserId,
            pageId: cleanString(conversation.pageId),
            senderIdentityType:
              isPageSenderIdentity(conversation, senderUserId)
                ? "page"
                : "user",
            title,
            body,
            previewText: body,
          };

          const staleTokens = new Set<string>();

          for (
            const tokenBatch of chunk(tokens, fcmBatchSize)
          ) {
            const response =
              await getMessaging().sendEachForMulticast({
                tokens: tokenBatch,
                notification: {
                  title,
                  body,
                },
                data,
                android: {
                  priority: "high",
                  notification: {
                    channelId: "luma_messages",
                    icon: "ic_launcher",
                    tag: `chat_${conversationId}`,
                    clickAction:
                      "FLUTTER_NOTIFICATION_CLICK",
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                    },
                  },
                },
              });

            response.responses.forEach(
              (sendResponse, index) => {
                if (sendResponse.success) {
                  return;
                }

                const failedToken =
                  tokenBatch[index];
                const code =
                  sendResponse.error?.code ?? "unknown";

                logger.warn(
                  "Messenger push token failed.",
                  {
                    recipientUserId,
                    conversationId,
                    messageId,
                    code,
                  },
                );

                if (
                  code ===
                    "messaging/registration-token-not-registered" ||
                  code ===
                    "messaging/invalid-registration-token"
                ) {
                  staleTokens.add(failedToken);
                }
              },
            );
          }

          if (staleTokens.size > 0) {
            await deleteStaleTokens(
              recipientUserId,
              staleTokens,
            );
          }

          logger.info(
            "Messenger push sent without activity notification.",
            {
              recipientUserId,
              conversationId,
              messageId,
              senderUserId,
            },
          );
        }),
      );
    },
  );

export const sendPushOnNewNotification =
  onDocumentCreated(
    {
      document:
        `${usersCollection}/{userId}/` +
        `${notificationsCollection}/{notificationId}`,
      region: "europe-west3",
      maxInstances: 20,
    },
    async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn(
        "Notification push skipped: missing snapshot.",
      );
      return;
    }

    const recipientUserId = cleanString(event.params.userId);
    const notificationId = cleanString(event.params.notificationId);
    const notification = snapshot.data() as UnknownRecord;

    if (!recipientUserId || !notificationId) {
      return;
    }

    const storedRecipientUserId =
      cleanString(notification.userId);

    if (
      storedRecipientUserId &&
      storedRecipientUserId !== recipientUserId
    ) {
      logger.warn(
        "Notification push skipped: recipient mismatch.",
        {
          recipientUserId,
          storedRecipientUserId,
          notificationId,
        },
      );
      return;
    }

    if (notification.isRead === true) {
      return;
    }

    const actorUserId = cleanString(notification.actorUserId);

    if (
      actorUserId &&
      actorUserId === recipientUserId
    ) {
      return;
    }

    const type = cleanString(notification.type);
    const settings =
      await loadUserNotificationSettings(recipientUserId);

    if (!isPushAllowedForType(type, settings)) {
      logger.info(
        "Notification push skipped by settings.",
        {
          recipientUserId,
          notificationId,
          type,
        },
      );
      return;
    }

    const tokens = await loadNotificationTokens(recipientUserId);

    if (tokens.length === 0) {
      logger.info(
        "Notification push skipped: no registered tokens.",
        {
          recipientUserId,
          notificationId,
          type,
        },
      );
      return;
    }

    const title =
      cleanString(notification.title) || "Luma";

    const body =
      cleanString(notification.body) ||
      "Du hast eine neue Benachrichtigung.";

    const targetType =
      cleanString(notification.targetType) || "system";

    const referenceId =
      cleanString(notification.referenceId);

    const secondaryReferenceId =
      cleanString(notification.secondaryReferenceId);

    const data = buildPushData({
      notificationId,
      recipientUserId,
      notification,
      type,
      targetType,
      referenceId,
      secondaryReferenceId,
    });

    const channelId =
      type === "directMessage"
        ? "luma_messages"
        : "luma_social_notifications";

    const staleTokens = new Set<string>();

    for (const tokenBatch of chunk(tokens, fcmBatchSize)) {
      const response =
        await getMessaging().sendEachForMulticast({
          tokens: tokenBatch,
          notification: {
            title,
            body,
          },
          data,
          android: {
            priority: "high",
            notification: {
              channelId,
              icon: "ic_launcher",
              tag: notificationTag({
                type,
                notificationId,
                referenceId,
              }),
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });

      response.responses.forEach((sendResponse, index) => {
        if (sendResponse.success) {
          return;
        }

        const failedToken = tokenBatch[index];
        const code =
          sendResponse.error?.code ?? "unknown";

        logger.warn(
          "Notification push token failed.",
          {
            recipientUserId,
            notificationId,
            type,
            code,
          },
        );

        if (
          code ===
            "messaging/registration-token-not-registered" ||
          code ===
            "messaging/invalid-registration-token"
        ) {
          staleTokens.add(failedToken);
        }
      });
    }

    if (staleTokens.size > 0) {
      await deleteStaleTokens(
        recipientUserId,
        staleTokens,
      );
    }

    await snapshot.ref.set(
      {
        pushSentAt: FieldValue.serverTimestamp(),
        pushDeliveryAttempted: true,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  },
);


function buildPushData(input: {
  notificationId: string;
  recipientUserId: string;
  notification: UnknownRecord;
  type: string;
  targetType: string;
  referenceId: string;
  secondaryReferenceId: string;
}): Record<string, string> {
  const values: Record<string, string> = {
    notificationId: input.notificationId,
    recipientUserId: input.recipientUserId,
    type: input.type,
    targetType: input.targetType,
  };

  addIfNotEmpty(
    values,
    "referenceId",
    input.referenceId,
  );

  addIfNotEmpty(
    values,
    "targetId",
    input.referenceId,
  );

  addIfNotEmpty(
    values,
    "secondaryReferenceId",
    input.secondaryReferenceId,
  );

  addIfNotEmpty(
    values,
    "actorUserId",
    cleanString(input.notification.actorUserId),
  );

  addIfNotEmpty(
    values,
    "profileId",
    input.targetType === "profile"
      ? input.referenceId
      : "",
  );

  addIfNotEmpty(
    values,
    "postId",
    input.targetType === "post" ||
      input.targetType === "comment"
      ? input.referenceId
      : "",
  );

  addIfNotEmpty(
    values,
    "commentId",
    input.targetType === "comment"
      ? input.secondaryReferenceId
      : "",
  );

  addIfNotEmpty(
    values,
    "conversationId",
    input.targetType === "chat"
      ? input.referenceId
      : cleanString(
        input.notification.conversationId,
      ),
  );

  addIfNotEmpty(
    values,
    "messageId",
    input.targetType === "chat"
      ? input.secondaryReferenceId
      : cleanString(input.notification.messageId),
  );

  addIfNotEmpty(
    values,
    "storyId",
    input.targetType === "story"
      ? input.referenceId
      : "",
  );

  addIfNotEmpty(
    values,
    "title",
    cleanString(input.notification.title),
  );

  addIfNotEmpty(
    values,
    "body",
    cleanString(input.notification.body),
  );

  addIfNotEmpty(
    values,
    "previewText",
    cleanString(input.notification.previewText),
  );

  return values;
}

function isPushAllowedForType(
  type: string,
  settings: NotificationSettings,
): boolean {
  if (!settings.pushNotificationsEnabled) {
    return false;
  }

  switch (type) {
    case "directMessage":
      return settings.messageNotificationsEnabled;

    case "friendRequest":
    case "friendRequestAccepted":
      return settings.friendRequestNotificationsEnabled;

    case "storyReply":
    case "storyReaction":
    case "storyPosted":
      return settings.storyNotificationsEnabled;

    case "storyView":
      return false;

    case "postLike":
    case "postComment":
    case "commentReply":
    case "mention":
    case "postShared":
    case "pageActivity":
    case "follow":
    case "groupActivity":
      return settings.activityNotificationsEnabled;

    case "securityAlert":
    case "systemUpdate":
      return true;

    default:
      return settings.activityNotificationsEnabled;
  }
}

async function loadUserNotificationSettings(
  userId: string,
): Promise<NotificationSettings> {
  const settingsSnapshot = await db
    .collection(usersCollection)
    .doc(userId)
    .collection("settings")
    .doc("app")
    .get();

  const data = settingsSnapshot.data() ?? {};

  return {
    pushNotificationsEnabled:
      data.pushNotificationsEnabled !== false,

    messageNotificationsEnabled:
      data.messageNotificationsEnabled !== false,

    activityNotificationsEnabled:
      data.activityNotificationsEnabled !== false,

    storyNotificationsEnabled:
      data.storyNotificationsEnabled !== false,

    friendRequestNotificationsEnabled:
      data.friendRequestNotificationsEnabled !== false,
  };
}

async function loadNotificationTokens(
  userId: string,
): Promise<string[]> {
  const snapshot = await db
    .collection(usersCollection)
    .doc(userId)
    .collection(notificationTokensCollection)
    .limit(maxNotificationTokensPerUser)
    .get();

  const tokens = new Set<string>();

  for (const document of snapshot.docs) {
    const data =
      document.data() as NotificationTokenDocument;

    const token = cleanString(data.token);
    const storedUserId = cleanString(data.userId);

    if (
      storedUserId &&
      storedUserId !== userId
    ) {
      continue;
    }

    if (
      token.length > 20 &&
      token.length <= 4096
    ) {
      tokens.add(token);
    }
  }

  return Array.from(tokens);
}

async function deleteStaleTokens(
  userId: string,
  staleTokens: Set<string>,
): Promise<void> {
  const snapshot = await db
    .collection(usersCollection)
    .doc(userId)
    .collection(notificationTokensCollection)
    .limit(maxNotificationTokensPerUser)
    .get();

  const batch = db.batch();
  let deleteCount = 0;

  for (const document of snapshot.docs) {
    const data =
      document.data() as NotificationTokenDocument;

    const token = cleanString(data.token);

    if (!staleTokens.has(token)) {
      continue;
    }

    batch.delete(document.ref);
    deleteCount += 1;
  }

  if (deleteCount === 0) {
    return;
  }

  await batch.commit();

  logger.info(
    "Deleted stale notification tokens.",
    {
      userId,
      deleteCount,
    },
  );
}

function messengerNotificationBody(
  message: MessageDocument,
): string {
  const messageType =
    cleanString(message.messageType);

  const text = cleanString(message.text);

  if (messageType === "image") {
    return text || "Hat dir ein Foto gesendet.";
  }

  if (messageType === "audio") {
    return "Hat dir eine Sprachnachricht gesendet.";
  }

  if (messageType === "file") {
    return text || "Hat dir eine Datei gesendet.";
  }

  if (text) {
    return limitText(text, 120);
  }

  return "Hat dir eine Nachricht gesendet.";
}

function isPageSenderIdentity(
  conversation: ConversationDocument,
  senderUserId: string,
): boolean {
  const conversationType =
    cleanString(conversation.conversationType);
  const pageId = cleanString(conversation.pageId);
  const pageOwnerUserId =
    cleanString(conversation.pageOwnerUserId);
  const pageTeamUserIds =
    readStringArray(conversation.pageTeamUserIds);

  if (conversationType !== "pageSupport" || !pageId) {
    return false;
  }

  return senderUserId === pageOwnerUserId ||
    pageTeamUserIds.includes(senderUserId);
}

async function loadSenderIdentity(input: {
  senderUserId: string;
  conversation: ConversationDocument;
  conversationFallback: ParticipantPreview;
}): Promise<ParticipantPreview> {
  if (
    isPageSenderIdentity(
      input.conversation,
      input.senderUserId,
    )
  ) {
    const pageIdentity =
      await loadPageIdentity(input.conversation);

    if (pageIdentity) {
      return pageIdentity;
    }
  }

  return loadUserProfile(
    input.senderUserId,
    input.conversationFallback,
  );
}

async function loadPageIdentity(
  conversation: ConversationDocument,
): Promise<ParticipantPreview | null> {
  const pageId = cleanString(conversation.pageId);

  if (!pageId) {
    return null;
  }

  const storedName = firstRealString([
    conversation.pageName,
    conversation.pageUsername,
  ]);
  const storedUsername =
    cleanString(conversation.pageUsername);
  const storedAvatarUrl =
    cleanString(conversation.pageAvatarUrl);

  try {
    const pageSnapshot = await db
      .collection("pages")
      .doc(pageId)
      .get();

    if (!pageSnapshot.exists) {
      return {
        userId: pageId,
        displayName: storedName || "Luma Page",
        username: storedUsername,
        avatarUrl: storedAvatarUrl,
      };
    }

    const data = pageSnapshot.data() ?? {};

    return {
      userId: pageId,
      displayName: firstRealString([
        data.name,
        data.displayName,
        storedName,
      ]) || "Luma Page",
      username: firstRealString([
        data.username,
        storedUsername,
      ]),
      avatarUrl: firstRealString([
        data.profileImageUrl,
        data.avatarUrl,
        storedAvatarUrl,
      ]),
    };
  } catch (error) {
    logger.error(
      "Messenger Page identity load failed.",
      {
        pageId,
        error,
      },
    );

    return {
      userId: pageId,
      displayName: storedName || "Luma Page",
      username: storedUsername,
      avatarUrl: storedAvatarUrl,
    };
  }
}

async function loadUserProfile(
  userId: string,
  conversationFallback: ParticipantPreview,
): Promise<ParticipantPreview> {
  const cleanedUserId = cleanString(userId);

  if (!cleanedUserId) {
    return unavailableParticipantPreview("");
  }

  try {
    const userSnapshot = await db
      .collection(usersCollection)
      .doc(cleanedUserId)
      .get();

    if (!userSnapshot.exists) {
      logger.warn(
        "Messenger sender profile missing.",
        {
          senderUserId: cleanedUserId,
        },
      );

      return sanitizeParticipantPreview(
        conversationFallback,
        cleanedUserId,
      );
    }

    const data = userSnapshot.data() ?? {};

    const displayName = firstRealString([
      data.displayName,
      data.name,
      data.fullName,
      data.username,
    ]);

    const username = firstRealString([
      data.username,
    ]);

    const avatarUrl = firstRealString([
      data.avatarUrl,
      data.profileImageUrl,
      data.photoUrl,
      data.photoURL,
    ]);

    return {
      userId: cleanedUserId,
      displayName: displayName || "Nutzer nicht mehr verfügbar",
      username,
      avatarUrl,
    };
  } catch (error) {
    logger.error(
      "Messenger sender profile load failed.",
      {
        senderUserId: cleanedUserId,
        error,
      },
    );

    return sanitizeParticipantPreview(
      conversationFallback,
      cleanedUserId,
    );
  }
}

function sanitizeParticipantPreview(
  preview: ParticipantPreview,
  userId: string,
): ParticipantPreview {
  const displayName = firstRealString([
    preview.displayName,
    preview.username,
  ]);

  return {
    userId,
    displayName: displayName || "Nutzer nicht mehr verfügbar",
    username: isPlaceholderIdentity(preview.username)
      ? ""
      : cleanString(preview.username),
    avatarUrl: cleanString(preview.avatarUrl),
  };
}

function unavailableParticipantPreview(
  userId: string,
): ParticipantPreview {
  return {
    userId,
    displayName: "Nutzer nicht mehr verfügbar",
    username: "",
    avatarUrl: "",
  };
}

function firstRealString(values: unknown[]): string {
  for (const value of values) {
    const cleaned = cleanString(value);

    if (cleaned && !isPlaceholderIdentity(cleaned)) {
      return cleaned;
    }
  }

  return "";
}

function isPlaceholderIdentity(value: unknown): boolean {
  const normalized = cleanString(value).toLowerCase();

  return normalized === "luma" ||
    normalized === "luma nutzer" ||
    normalized === "luma user" ||
    normalized === "du" ||
    normalized === "you" ||
    normalized === "mock user" ||
    normalized === "unknown user";
}

function findParticipantPreview(
  rawParticipants: unknown,
  userId: string,
): ParticipantPreview {
  if (!Array.isArray(rawParticipants)) {
    return {
      userId,
      displayName: "Nutzer nicht mehr verfügbar",
      username: "",
      avatarUrl: "",
    };
  }

  for (const item of rawParticipants) {
    if (!isRecord(item)) {
      continue;
    }

    const itemUserId =
      cleanString(item.userId);

    if (itemUserId !== userId) {
      continue;
    }

    return {
      userId,
      displayName:
        cleanString(item.displayName) ||
        cleanString(item.name) ||
        cleanString(item.username) ||
        "Nutzer nicht mehr verfügbar",
      username: cleanString(item.username),
      avatarUrl:
        cleanString(item.avatarUrl) ||
        cleanString(item.profileImageUrl),
    };
  }

  return {
    userId,
    displayName: "Luma",
    username: "",
    avatarUrl: "",
  };
}

function notificationTag(input: {
  type: string;
  notificationId: string;
  referenceId: string;
}): string {
  if (
    input.type === "directMessage" &&
    input.referenceId
  ) {
    return `chat_${input.referenceId}`;
  }

  return input.notificationId;
}

function addIfNotEmpty(
  target: Record<string, string>,
  key: string,
  value: string,
): void {
  const cleanedValue = value.trim();

  if (!cleanedValue) {
    return;
  }

  target[key] = cleanedValue;
}


function readStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => cleanString(item))
    .filter((item) => item.length > 0);
}

function cleanString(value: unknown): string {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim();
}

function limitText(
  value: string,
  maxLength: number,
): string {
  const cleaned = value.trim();

  if (cleaned.length <= maxLength) {
    return cleaned;
  }

  return `${cleaned
    .substring(0, Math.max(0, maxLength - 1))
    .trim()}…`;
}

function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

function chunk<T>(
  items: T[],
  size: number,
): T[][] {
  if (size <= 0) {
    return [items];
  }

  const chunks: T[][] = [];

  for (
    let index = 0;
    index < items.length;
    index += size
  ) {
    chunks.push(
      items.slice(index, index + size),
    );
  }

  return chunks;
}
