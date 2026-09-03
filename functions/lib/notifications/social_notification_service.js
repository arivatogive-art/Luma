"use strict";
// Pfad: functions/src/notifications/social_notification_service.ts
// Push Navigation 2.0: eindeutige Deep-Link-Payloads für Luma.
Object.defineProperty(exports, "__esModule", { value: true });
exports.createOrGroupSocialNotification = createOrGroupSocialNotification;
exports.deleteSocialNotificationByGroupKey = deleteSocialNotificationByGroupKey;
const firestore_1 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const firebase_functions_1 = require("firebase-functions");
const db = (0, firestore_1.getFirestore)();
const usersCollection = "users";
const notificationsCollection = "notifications";
const notificationTokensCollection = "notification_tokens";
const settingsCollection = "settings";
const appSettingsDocument = "app";
async function createOrGroupSocialNotification(input) {
    const recipientUserId = cleanString(input.recipientUserId);
    const actorUserId = cleanString(input.actorUserId);
    const groupKey = cleanString(input.groupKey);
    const deduplicationKey = cleanString(input.deduplicationKey);
    const referenceId = cleanString(input.referenceId);
    if (!recipientUserId || !actorUserId) {
        firebase_functions_1.logger.warn("SOCIAL_NOTIFICATION_SKIPPED_INVALID_USER", {
            recipientUserId,
            actorUserId,
            type: input.type,
        });
        return;
    }
    if (recipientUserId === actorUserId) {
        return;
    }
    if (!groupKey || !deduplicationKey || !referenceId) {
        firebase_functions_1.logger.warn("SOCIAL_NOTIFICATION_SKIPPED_INVALID_TARGET", {
            recipientUserId,
            actorUserId,
            type: input.type,
            groupKey,
            deduplicationKey,
            referenceId,
        });
        return;
    }
    const [actor, settings, blocked] = await Promise.all([
        loadActorSnapshot(actorUserId),
        loadNotificationSettings(recipientUserId),
        isBlockedBetweenUsers(recipientUserId, actorUserId),
    ]);
    if (blocked || actor === null) {
        return;
    }
    if (!settings.inAppNotificationsEnabled) {
        return;
    }
    if (!isNotificationTypeEnabled(input.type, settings)) {
        return;
    }
    const notificationId = stableDocumentId(groupKey);
    const notificationReference = db
        .collection(usersCollection)
        .doc(recipientUserId)
        .collection(notificationsCollection)
        .doc(notificationId);
    let finalBody = "";
    let finalGroupCount = 1;
    let shouldPush = false;
    await db.runTransaction(async (transaction) => {
        const existingSnapshot = await transaction.get(notificationReference);
        const existingData = existingSnapshot.data() ?? {};
        const existingDeduplicationKeys = readStringArray(existingData.deduplicationKeys);
        if (existingDeduplicationKeys.includes(deduplicationKey)) {
            return;
        }
        const actorUserIds = new Set(readStringArray(existingData.actorUserIds));
        actorUserIds.add(actor.userId);
        const nextDeduplicationKeys = [
            ...existingDeduplicationKeys,
            deduplicationKey,
        ].slice(-100);
        const nextActorUserIds = Array.from(actorUserIds).slice(-100);
        finalGroupCount = Math.max(readPositiveNumber(existingData.groupCount) + 1, nextActorUserIds.length, 1);
        finalBody = input.bodyBuilder(actor.displayName, finalGroupCount);
        const payload = {
            id: notificationId,
            userId: recipientUserId,
            actorUserId: actor.userId,
            actorDisplayName: actor.displayName,
            actorUsername: actor.username,
            actorAvatarUrl: actor.avatarUrl,
            type: input.type,
            priority: input.priority,
            targetType: input.targetType,
            referenceId,
            secondaryReferenceId: cleanNullableString(input.secondaryReferenceId),
            friendshipId: cleanNullableString(input.friendshipId),
            previewText: cleanNullableString(input.previewText),
            contentThumbnailUrl: cleanNullableString(input.contentThumbnailUrl),
            groupKey,
            deduplicationKey,
            deduplicationKeys: nextDeduplicationKeys,
            groupCount: finalGroupCount,
            actorUserIds: nextActorUserIds,
            title: cleanString(input.title),
            body: finalBody,
            createdAt: existingSnapshot.exists
                ? existingData.createdAt ?? firestore_1.FieldValue.serverTimestamp()
                : firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            readAt: null,
            isRead: false,
            isActionable: input.isActionable !== false,
            schemaVersion: 3,
            friendRequestStatus: input.friendRequestStatus ?? null,
        };
        transaction.set(notificationReference, payload, { merge: true });
        shouldPush =
            settings.pushNotificationsEnabled &&
                shouldSendPushForType(input.type, input.priority) &&
                (!settings.quietModeEnabled ||
                    (input.type === "securityAlert" &&
                        settings.quietModeAllowSecurityAlerts));
    });
    if (!shouldPush || !finalBody) {
        return;
    }
    const explicitTargetIds = resolveExplicitTargetIds({
        targetType: input.targetType,
        referenceId,
        secondaryReferenceId: cleanNullableString(input.secondaryReferenceId),
        postId: cleanNullableString(input.postId),
        commentId: cleanNullableString(input.commentId),
        profileId: cleanNullableString(input.profileId),
        storyId: cleanNullableString(input.storyId),
    });
    await sendPushToUser({
        recipientUserId,
        title: input.title,
        body: finalBody,
        notificationId,
        type: input.type,
        targetType: input.targetType,
        referenceId,
        secondaryReferenceId: cleanNullableString(input.secondaryReferenceId),
        ...explicitTargetIds,
    });
}
async function deleteSocialNotificationByGroupKey(recipientUserId, groupKey) {
    const cleanedRecipientId = cleanString(recipientUserId);
    const cleanedGroupKey = cleanString(groupKey);
    if (!cleanedRecipientId || !cleanedGroupKey)
        return;
    const notificationId = stableDocumentId(cleanedGroupKey);
    await db
        .collection(usersCollection)
        .doc(cleanedRecipientId)
        .collection(notificationsCollection)
        .doc(notificationId)
        .delete()
        .catch(() => undefined);
}
async function loadActorSnapshot(userId) {
    const snapshot = await db.collection(usersCollection).doc(userId).get();
    if (!snapshot.exists)
        return null;
    const data = snapshot.data() ?? {};
    const displayName = cleanString(data.displayName) || cleanString(data.name);
    const username = cleanString(data.username);
    const avatarUrl = cleanString(data.avatarUrl) ||
        cleanString(data.profileImageUrl) ||
        cleanString(data.photoUrl) ||
        cleanString(data.photoURL);
    if (!displayName && !username) {
        return null;
    }
    return {
        userId,
        displayName: displayName || username.replace(/^@/, ""),
        username,
        avatarUrl,
    };
}
async function loadNotificationSettings(userId) {
    const snapshot = await db
        .collection(usersCollection)
        .doc(userId)
        .collection(settingsCollection)
        .doc(appSettingsDocument)
        .get();
    const data = snapshot.data() ?? {};
    return {
        pushNotificationsEnabled: readBool(data.pushNotificationsEnabled, true),
        inAppNotificationsEnabled: readBool(data.inAppNotificationsEnabled, true),
        likeNotificationsEnabled: readBool(data.likeNotificationsEnabled, true),
        commentNotificationsEnabled: readBool(data.commentNotificationsEnabled, true),
        replyNotificationsEnabled: readBool(data.replyNotificationsEnabled, true),
        friendRequestNotificationsEnabled: readBool(data.friendRequestNotificationsEnabled, true),
        mentionNotificationsEnabled: readBool(data.mentionNotificationsEnabled, true),
        quietModeEnabled: readBool(data.quietModeEnabled, false),
        quietModeAllowSecurityAlerts: readBool(data.quietModeAllowSecurityAlerts, true),
    };
}
async function isBlockedBetweenUsers(firstUserId, secondUserId) {
    const [firstBlock, secondBlock] = await Promise.all([
        db
            .collection(usersCollection)
            .doc(firstUserId)
            .collection("blockedUsers")
            .doc(secondUserId)
            .get(),
        db
            .collection(usersCollection)
            .doc(secondUserId)
            .collection("blockedUsers")
            .doc(firstUserId)
            .get(),
    ]);
    return isActiveBlock(firstBlock.data()) || isActiveBlock(secondBlock.data());
}
function isActiveBlock(data) {
    if (!data)
        return false;
    return data.isActive !== false;
}
function isNotificationTypeEnabled(type, settings) {
    switch (type) {
        case "postLike":
        case "commentLike":
            return settings.likeNotificationsEnabled;
        case "postComment":
            return settings.commentNotificationsEnabled;
        case "commentReply":
            return settings.replyNotificationsEnabled;
        case "friendRequest":
        case "friendRequestAccepted":
            return settings.friendRequestNotificationsEnabled;
        case "mention":
            return settings.mentionNotificationsEnabled;
        default:
            return true;
    }
}
function shouldSendPushForType(type, priority) {
    if (type === "securityAlert")
        return true;
    if (priority === "high")
        return true;
    return [
        "postComment",
        "commentReply",
        "friendRequest",
        "friendRequestAccepted",
        "mention",
    ].includes(type);
}
async function sendPushToUser(input) {
    const tokensSnapshot = await db
        .collection(usersCollection)
        .doc(input.recipientUserId)
        .collection(notificationTokensCollection)
        .limit(500)
        .get();
    const tokenDocuments = tokensSnapshot.docs.filter((document) => {
        const token = cleanString(document.data().token);
        return token.length > 20;
    });
    if (tokenDocuments.length === 0) {
        return;
    }
    const tokens = tokenDocuments.map((document) => cleanString(document.data().token));
    const message = {
        tokens,
        notification: {
            title: cleanString(input.title),
            body: cleanString(input.body),
        },
        data: {
            notificationId: input.notificationId,
            type: input.type,
            targetType: input.targetType,
            // Kanonische IDs bleiben für Rückwärtskompatibilität erhalten.
            referenceId: input.referenceId,
            secondaryReferenceId: input.secondaryReferenceId ?? "",
            // Explizite Ziel-IDs verhindern, dass die App raten muss, ob eine
            // referenceId einen Beitrag, Kommentar, ein Profil oder eine Story meint.
            postId: input.postId ?? "",
            commentId: input.commentId ?? "",
            profileId: input.profileId ?? "",
            storyId: input.storyId ?? "",
            navigationVersion: "2",
            source: "social_notification",
        },
        android: {
            priority: "high",
            notification: {
                channelId: "luma_social_notifications",
                sound: "default",
            },
        },
        webpush: {
            fcmOptions: {
                link: buildWebPushLink(input),
            },
        },
    };
    const response = await (0, messaging_1.getMessaging)().sendEachForMulticast(message);
    const invalidTokenDocuments = [];
    response.responses.forEach((result, index) => {
        if (result.success)
            return;
        const errorCode = result.error?.code ?? "";
        if (errorCode === "messaging/registration-token-not-registered" ||
            errorCode === "messaging/invalid-registration-token") {
            invalidTokenDocuments.push(tokenDocuments[index]);
        }
        else {
            firebase_functions_1.logger.error("SOCIAL_PUSH_SEND_FAILED", {
                userId: input.recipientUserId,
                tokenDocumentId: tokenDocuments[index].id,
                errorCode,
            });
        }
    });
    if (invalidTokenDocuments.length === 0)
        return;
    const batch = db.batch();
    for (const document of invalidTokenDocuments) {
        batch.delete(document.ref);
    }
    await batch.commit();
}
function resolveExplicitTargetIds(input) {
    const referenceId = cleanString(input.referenceId);
    const secondaryReferenceId = cleanNullableString(input.secondaryReferenceId);
    switch (input.targetType) {
        case "post":
            return {
                postId: input.postId ?? referenceId,
                commentId: input.commentId,
                profileId: null,
                storyId: null,
            };
        case "comment":
            return {
                postId: input.postId ?? referenceId,
                commentId: input.commentId ?? secondaryReferenceId,
                profileId: null,
                storyId: null,
            };
        case "profile":
            return {
                postId: null,
                commentId: null,
                profileId: input.profileId ?? referenceId,
                storyId: null,
            };
        case "story":
            return {
                postId: null,
                commentId: null,
                profileId: null,
                storyId: input.storyId ?? referenceId,
            };
        case "group":
        case "page":
        case "system":
            return {
                postId: null,
                commentId: null,
                profileId: null,
                storyId: null,
            };
    }
}
function buildWebPushLink(input) {
    const parameters = new URLSearchParams({
        pushNavigation: "1",
        notificationId: input.notificationId,
        type: input.type,
        targetType: input.targetType,
        referenceId: input.referenceId,
    });
    if (input.secondaryReferenceId) {
        parameters.set("secondaryReferenceId", input.secondaryReferenceId);
    }
    if (input.postId)
        parameters.set("postId", input.postId);
    if (input.commentId)
        parameters.set("commentId", input.commentId);
    if (input.profileId)
        parameters.set("profileId", input.profileId);
    if (input.storyId)
        parameters.set("storyId", input.storyId);
    return `/?${parameters.toString()}`;
}
function stableDocumentId(value) {
    return Buffer.from(value, "utf8")
        .toString("base64url")
        .slice(0, 220);
}
function cleanString(value) {
    return typeof value === "string" ? value.trim() : "";
}
function cleanNullableString(value) {
    const cleaned = cleanString(value);
    return cleaned || null;
}
function readBool(value, fallback) {
    return typeof value === "boolean" ? value : fallback;
}
function readPositiveNumber(value) {
    if (typeof value !== "number" || !Number.isFinite(value)) {
        return 0;
    }
    return Math.max(0, Math.floor(value));
}
function readStringArray(value) {
    if (!Array.isArray(value))
        return [];
    return value
        .map((item) => cleanString(item))
        .filter((item) => item.length > 0);
}
//# sourceMappingURL=social_notification_service.js.map