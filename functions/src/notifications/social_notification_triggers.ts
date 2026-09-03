// Pfad: functions/src/notifications/social_notification_triggers.ts

    import {getFirestore} from "firebase-admin/firestore";
    import {
      onDocumentCreated,
      onDocumentDeleted,
      onDocumentUpdated,
    } from "firebase-functions/v2/firestore";
    import {
      createOrGroupSocialNotification,
      deleteSocialNotificationByGroupKey,
    } from "./social_notification_service.js";

    const db = getFirestore();

    export const onPostCreated = onDocumentCreated(
      "feed_posts/{postId}",
      async (event) => {
        const snapshot = event.data;
        if (!snapshot) return;

        const postId = cleanString(event.params.postId);
        const data = snapshot.data() ?? {};
        const actorUserId =
          cleanString(data.authorId) || cleanString(data.userId);

        if (!postId || !actorUserId) return;

        const text = firstNonEmptyString(
          data.text,
          data.content,
          data.caption,
          data.description,
        );

        if (!text) return;

        await createMentionNotifications({
          actorUserId,
          text,
          targetType: "post",
          referenceId: postId,
          previewText: text.slice(0, 220),
          excludedRecipientUserIds: new Set<string>(),
        });
      },
    );


    export const onPostLikeCreated = onDocumentCreated(
      "feed_posts/{postId}/liked_by/{actorUserId}",
      async (event) => {
        const postId = cleanString(event.params.postId);
        const actorUserId = cleanString(event.params.actorUserId);

        const postSnapshot = await db.collection("feed_posts").doc(postId).get();
        if (!postSnapshot.exists) return;

        const postData = postSnapshot.data() ?? {};
        const recipientUserId =
          cleanString(postData.authorId) || cleanString(postData.userId);

        if (!recipientUserId || recipientUserId === actorUserId) return;

        await createOrGroupSocialNotification({
          recipientUserId,
          actorUserId,
          type: "postLike",
          priority: "low",
          targetType: "post",
          referenceId: postId,
          groupKey: `postLike:${recipientUserId}:${postId}`,
          deduplicationKey: `postLike:${postId}:${actorUserId}`,
          title: "Neue Reaktion",
          bodyBuilder: (actorLabel, groupCount) => {
            if (groupCount <= 1) {
              return `${actorLabel} gefällt dein Beitrag.`;
            }

            return `${groupCount} Personen gefällt dein Beitrag.`;
          },
        });
      },
    );

    export const onPostLikeDeleted = onDocumentDeleted(
      "feed_posts/{postId}/liked_by/{actorUserId}",
      async (event) => {
        const postId = cleanString(event.params.postId);
        const actorUserId = cleanString(event.params.actorUserId);

        const postSnapshot = await db.collection("feed_posts").doc(postId).get();
        if (!postSnapshot.exists) return;

        const postData = postSnapshot.data() ?? {};
        const recipientUserId =
          cleanString(postData.authorId) || cleanString(postData.userId);

        if (!recipientUserId || recipientUserId === actorUserId) return;

        // Bei vollständiger Gruppierungsauflösung wird die Gruppe neu aufgebaut.
        // Für den ersten Produktionsblock wird die einzelne Gruppe entfernt,
        // sobald keine Likes mehr vorhanden sind.
        const remainingLikes = await db
          .collection("feed_posts")
          .doc(postId)
          .collection("liked_by")
          .limit(1)
          .get();

        if (remainingLikes.empty) {
          await deleteSocialNotificationByGroupKey(
            recipientUserId,
            `postLike:${recipientUserId}:${postId}`,
          );
        }
      },
    );

    export const onCommentCreated = onDocumentCreated(
      "feed_posts/{postId}/comments/{commentId}",
      async (event) => {
        const snapshot = event.data;
        if (!snapshot) return;

        const postId = cleanString(event.params.postId);
        const commentId = cleanString(event.params.commentId);
        const data = snapshot.data();

        if (data.isDeleted === true) return;

        const actorUserId =
          cleanString(data.authorId) || cleanString(data.userId);
        const parentCommentId = cleanString(data.parentCommentId);
        const replyToUserId = cleanString(data.replyToUserId);
        const previewText = cleanString(data.text).slice(0, 220);

        const postReference = db.collection("feed_posts").doc(postId);
        const postSnapshot = await postReference.get();

        if (!postSnapshot.exists) return;

        const postData = postSnapshot.data() ?? {};
        const postOwnerUserId =
          cleanString(postData.authorId) || cleanString(postData.userId);

        if (parentCommentId) {
          let recipientUserId = replyToUserId;

          if (!recipientUserId) {
            const parentSnapshot = await postReference
              .collection("comments")
              .doc(parentCommentId)
              .get();

            const parentData = parentSnapshot.data() ?? {};
            recipientUserId =
              cleanString(parentData.authorId) || cleanString(parentData.userId);
          }

          if (recipientUserId && recipientUserId !== actorUserId) {
            await createOrGroupSocialNotification({
              recipientUserId,
              actorUserId,
              type: "commentReply",
              priority: "high",
              targetType: "comment",
              referenceId: postId,
              secondaryReferenceId: commentId,
              previewText,
              groupKey:
                `commentReply:${recipientUserId}:${postId}:${parentCommentId}`,
              deduplicationKey: `commentReply:${postId}:${commentId}`,
              title: "Neue Antwort",
              bodyBuilder: (actorLabel, groupCount) => {
                if (groupCount <= 1) {
                  return `${actorLabel} hat deinen Kommentar beantwortet.`;
                }

                return `${groupCount} Personen haben deinen Kommentar beantwortet.`;
              },
            });
          }

          await createMentionNotifications({
            actorUserId,
            text: cleanString(data.text),
            targetType: "comment",
            referenceId: postId,
            secondaryReferenceId: commentId,
            previewText,
            excludedRecipientUserIds: new Set<string>([
              actorUserId,
              ...(recipientUserId ? [recipientUserId] : []),
            ]),
          });

          return;
        }

        if (postOwnerUserId && postOwnerUserId !== actorUserId) {

          await createOrGroupSocialNotification({
            recipientUserId: postOwnerUserId,
            actorUserId,
            type: "postComment",
            priority: "high",
            targetType: "comment",
            referenceId: postId,
            secondaryReferenceId: commentId,
            previewText,
            groupKey: `postComment:${postOwnerUserId}:${postId}`,
            deduplicationKey: `postComment:${postId}:${commentId}`,
            title: "Neuer Kommentar",
            bodyBuilder: (actorLabel, groupCount) => {
              if (groupCount <= 1) {
                return `${actorLabel} hat deinen Beitrag kommentiert.`;
              }

              return `${groupCount} Personen haben deinen Beitrag kommentiert.`;
            },
          });
        }

        await createMentionNotifications({
          actorUserId,
          text: cleanString(data.text),
          targetType: "comment",
          referenceId: postId,
          secondaryReferenceId: commentId,
          previewText,
          excludedRecipientUserIds: new Set<string>([
            actorUserId,
            ...(postOwnerUserId ? [postOwnerUserId] : []),
          ]),
        });

      },
    );


    export const onCommentLikeCreated = onDocumentCreated(
      "feed_posts/{postId}/comments/{commentId}/liked_by/{actorUserId}",
      async (event) => {
        const postId = cleanString(event.params.postId);
        const commentId = cleanString(event.params.commentId);
        const actorUserId = cleanString(event.params.actorUserId);

        const commentSnapshot = await db
          .collection("feed_posts")
          .doc(postId)
          .collection("comments")
          .doc(commentId)
          .get();

        if (!commentSnapshot.exists) return;

        const commentData = commentSnapshot.data() ?? {};
        if (commentData.isDeleted === true) return;

        const recipientUserId =
          cleanString(commentData.authorId) || cleanString(commentData.userId);
        if (!recipientUserId || recipientUserId === actorUserId) return;

        await createOrGroupSocialNotification({
          recipientUserId,
          actorUserId,
          type: "commentLike",
          priority: "low",
          targetType: "comment",
          referenceId: postId,
          secondaryReferenceId: commentId,
          groupKey:
            `commentLike:${recipientUserId}:${postId}:${commentId}`,
          deduplicationKey:
            `commentLike:${postId}:${commentId}:${actorUserId}`,
          title: "Neue Reaktion",
          bodyBuilder: (actorLabel, groupCount) => {
            if (groupCount <= 1) {
              return `${actorLabel} gefällt dein Kommentar.`;
            }

            return `${groupCount} Personen gefällt dein Kommentar.`;
          },
        });
      },
    );


    export const onCommentLikeDeleted = onDocumentDeleted(
      "feed_posts/{postId}/comments/{commentId}/liked_by/{actorUserId}",
      async (event) => {
        const postId = cleanString(event.params.postId);
        const commentId = cleanString(event.params.commentId);
        const actorUserId = cleanString(event.params.actorUserId);

        const commentSnapshot = await db
          .collection("feed_posts")
          .doc(postId)
          .collection("comments")
          .doc(commentId)
          .get();

        if (!commentSnapshot.exists) return;

        const commentData = commentSnapshot.data() ?? {};
        const recipientUserId =
          cleanString(commentData.authorId) || cleanString(commentData.userId);

        if (!recipientUserId || recipientUserId === actorUserId) return;

        await deleteSocialNotificationByGroupKey(
          recipientUserId,
          `commentLike:${recipientUserId}:${postId}:${commentId}`,
        );
      },
    );

    export const onFriendshipCreated = onDocumentCreated(
      "friendships/{friendshipId}",
      async (event) => {
        const snapshot = event.data;
        if (!snapshot) return;

        const data = snapshot.data();
        if (cleanString(data.status) !== "pending") return;

        const friendshipId = cleanString(event.params.friendshipId);
        const requesterUserId = cleanString(data.requesterUserId);
        const addresseeUserId = cleanString(data.addresseeUserId);

        if (!requesterUserId || !addresseeUserId) return;

        await createOrGroupSocialNotification({
          recipientUserId: addresseeUserId,
          actorUserId: requesterUserId,
          type: "friendRequest",
          priority: "high",
          targetType: "profile",
          referenceId: requesterUserId,
          friendshipId,
          groupKey:
            `friendRequest:${addresseeUserId}:${friendshipId}`,
          deduplicationKey:
            `friendRequest:${friendshipId}:created`,
          title: "Neue Freundschaftsanfrage",
          friendRequestStatus: "pending",
          bodyBuilder: (actorLabel) => {
            return `${actorLabel} hat dir eine Freundschaftsanfrage gesendet.`;
          },
        });
      },
    );

    export const onFriendshipUpdated = onDocumentUpdated(
      "friendships/{friendshipId}",
      async (event) => {
        const before = event.data?.before.data();
        const after = event.data?.after.data();

        if (!before || !after) return;

        const previousStatus = cleanString(before.status);
        const nextStatus = cleanString(after.status);

        if (previousStatus === nextStatus) return;

        const friendshipId = cleanString(event.params.friendshipId);
        const requesterUserId = cleanString(after.requesterUserId);
        const addresseeUserId = cleanString(after.addresseeUserId);

        if (!requesterUserId || !addresseeUserId) return;

        if (nextStatus === "accepted") {
          // Die eingehende Anfrage ist nach der Annahme abgeschlossen.
          // Sie wird serverseitig über denselben Group-Key entfernt, damit
          // niemals gleichzeitig eine offene und eine angenommene Anfrage
          // für dieselbe Freundschaft sichtbar bleibt.
          await deleteSocialNotificationByGroupKey(
            addresseeUserId,
            `friendRequest:${addresseeUserId}:${friendshipId}`,
          );

          await createOrGroupSocialNotification({
            recipientUserId: requesterUserId,
            actorUserId: addresseeUserId,
            type: "friendRequestAccepted",
            priority: "high",
            targetType: "profile",
            referenceId: addresseeUserId,
            friendshipId,
            groupKey:
              `friendRequestAccepted:${requesterUserId}:${friendshipId}`,
            deduplicationKey:
              `friendRequestAccepted:${friendshipId}`,
            title: "Freundschaft bestätigt",
            friendRequestStatus: "accepted",
            bodyBuilder: (actorLabel) => {
              return `${actorLabel} hat deine Freundschaftsanfrage angenommen.`;
            },
          });
        }

        if (
          nextStatus === "declined" ||
          nextStatus === "blocked"
        ) {
          await deleteSocialNotificationByGroupKey(
            addresseeUserId,
            `friendRequest:${addresseeUserId}:${friendshipId}`,
          );
        }
      },
    );

    async function createMentionNotifications(input: {
      actorUserId: string;
      text: string;
      targetType: "post" | "comment";
      referenceId: string;
      secondaryReferenceId?: string;
      previewText?: string;
      excludedRecipientUserIds: Set<string>;
    }): Promise<void> {
      const usernames = extractMentionUsernames(input.text);

      if (usernames.length === 0) return;

      const mentionedUsers = await resolveMentionedUsers(usernames);

      for (const mentionedUser of mentionedUsers) {
        const recipientUserId = mentionedUser.userId;

        if (
          !recipientUserId ||
          recipientUserId === input.actorUserId ||
          input.excludedRecipientUserIds.has(recipientUserId)
        ) {
          continue;
        }

        const eventReference = input.secondaryReferenceId
          ? `${input.referenceId}:${input.secondaryReferenceId}`
          : input.referenceId;

        const targetLabel =
          input.targetType === "comment" ? "Kommentar" : "Beitrag";

        await createOrGroupSocialNotification({
          recipientUserId,
          actorUserId: input.actorUserId,
          type: "mention",
          priority: "high",
          targetType: input.targetType,
          referenceId: input.referenceId,
          secondaryReferenceId: input.secondaryReferenceId,
          previewText: cleanString(input.previewText).slice(0, 220),
          groupKey:
            `mention:${recipientUserId}:${input.targetType}:${eventReference}`,
          deduplicationKey:
            `mention:${recipientUserId}:${input.targetType}:${eventReference}`,
          title: "Du wurdest erwähnt",
          bodyBuilder: (actorLabel) => {
            return `${actorLabel} hat dich in einem ${targetLabel} erwähnt.`;
          },
        });
      }
    }

    function extractMentionUsernames(text: string): string[] {
      const normalizedText = cleanString(text);
      if (!normalizedText) return [];

      const matches = normalizedText.matchAll(
        /(^|[\s([{])@([A-Za-z0-9._]{2,30})/g,
      );

      const usernames = new Set<string>();

      for (const match of matches) {
        const username = cleanString(match[2]).toLowerCase();
        if (username) usernames.add(username);
        if (usernames.size >= 10) break;
      }

      return Array.from(usernames);
    }

    async function resolveMentionedUsers(
      usernames: string[],
    ): Promise<Array<{userId: string; username: string}>> {
      const results = new Map<string, {userId: string; username: string}>();

      for (const username of usernames) {
        const candidates = new Set<string>([
          username,
          username.toLowerCase(),
        ]);

        for (const candidate of candidates) {
          const snapshot = await db
            .collection("users")
            .where("username", "==", candidate)
            .limit(2)
            .get();

          for (const document of snapshot.docs) {
            const data = document.data() ?? {};
            const storedUsername = cleanString(data.username).toLowerCase();

            if (storedUsername !== username.toLowerCase()) continue;

            results.set(document.id, {
              userId: document.id,
              username: storedUsername,
            });
          }

          if (results.size >= usernames.length) break;
        }
      }

      return Array.from(results.values());
    }

    function firstNonEmptyString(...values: unknown[]): string {
      for (const value of values) {
        const cleaned = cleanString(value);
        if (cleaned) return cleaned;
      }

      return "";
    }

    function cleanString(value: unknown): string {
      return typeof value === "string" ? value.trim() : "";
    }
