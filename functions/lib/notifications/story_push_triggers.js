"use strict";
// Pfad: functions/src/notifications/story_push_triggers.ts
//
// Luma Story Benachrichtigung:
// - reagiert serverseitig sofort auf eine neu erstellte Story
// - respektiert die gespeicherte Story-Zielgruppe
// - erzeugt genau EINE dauerhafte In-App-Benachrichtigung pro Empfänger
// - der bestehende sendPushOnNewNotification-Trigger verschickt daraus den Push
// - KEIN direkter zweiter Story-Push mehr
// - verändert KEINE Story-, Freundschafts- oder UI-Logik
Object.defineProperty(exports, "__esModule", { value: true });
exports.onStoryCreatedSendPush = void 0;
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
const firestore_2 = require("firebase-functions/v2/firestore");
const db = (0, firestore_1.getFirestore)();
const usersCollection = "users";
const friendshipsCollection = "friendships";
const notificationsCollection = "notifications";
const recipientConcurrency = 20;
exports.onStoryCreatedSendPush = (0, firestore_2.onDocumentCreated)({
    document: "stories/{storyId}",
    region: "europe-west3",
    maxInstances: 20,
    timeoutSeconds: 120,
    memory: "256MiB",
}, async (event) => {
    const snapshot = event.data;
    const storyId = cleanString(event.params.storyId);
    if (!snapshot || !storyId) {
        return;
    }
    const story = snapshot.data() ?? {};
    const authorUserId = cleanString(story.authorId);
    const isArchived = story.isArchived === true;
    if (!authorUserId || isArchived) {
        return;
    }
    const actor = {
        userId: authorUserId,
        displayName: cleanString(story.authorName) ||
            cleanString(story.authorUsername),
        username: cleanString(story.authorUsername),
        avatarUrl: cleanString(story.authorProfileImageUrl),
    };
    const visibilityType = normalizeVisibilityType(story.visibilityType);
    const recipientUserIds = await resolveStoryRecipients({
        authorUserId,
        visibilityType,
        audienceUserIds: readStringArray(story.audienceUserIds),
    });
    if (recipientUserIds.length === 0) {
        firebase_functions_1.logger.info("STORY_NOTIFICATION_SKIPPED_WITHOUT_RECIPIENTS", {
            storyId,
            authorUserId,
            visibilityType,
        });
        return;
    }
    for (let offset = 0; offset < recipientUserIds.length; offset += recipientConcurrency) {
        const recipientChunk = recipientUserIds.slice(offset, offset + recipientConcurrency);
        await Promise.all(recipientChunk.map((recipientUserId) => createStoryNotification({
            recipientUserId,
            actor,
            storyId,
        })));
    }
    firebase_functions_1.logger.info("STORY_NOTIFICATION_CREATED", {
        storyId,
        authorUserId,
        visibilityType,
        recipientCount: recipientUserIds.length,
    });
});
async function createStoryNotification(input) {
    if (!input.recipientUserId ||
        input.recipientUserId === input.actor.userId) {
        return;
    }
    const notificationId = `story_posted_${input.storyId}`;
    const body = `${safeActorLabel(input.actor)} hat eine Story gepostet.`;
    const notificationReference = db
        .collection(usersCollection)
        .doc(input.recipientUserId)
        .collection(notificationsCollection)
        .doc(notificationId);
    await notificationReference.set({
        id: notificationId,
        userId: input.recipientUserId,
        actorUserId: input.actor.userId,
        actorDisplayName: input.actor.displayName,
        actorUsername: input.actor.username,
        actorAvatarUrl: input.actor.avatarUrl,
        type: "storyPosted",
        priority: "medium",
        targetType: "story",
        referenceId: input.storyId,
        secondaryReferenceId: null,
        friendshipId: null,
        previewText: null,
        contentThumbnailUrl: null,
        groupKey: `storyPosted:${input.recipientUserId}:${input.storyId}`,
        deduplicationKey: `storyPosted:${input.storyId}`,
        groupCount: 1,
        actorUserIds: [input.actor.userId],
        actorDisplayNames: input.actor.displayName
            ? [input.actor.displayName]
            : [],
        groupedNotificationIds: [notificationId],
        unreadNotificationIds: [notificationId],
        title: "Neue Story",
        body,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        readAt: null,
        isRead: false,
        isActionable: true,
        schemaVersion: 4,
        friendRequestStatus: null,
        storyId: input.storyId,
        source: "story_posted",
    }, { merge: true });
}
async function resolveStoryRecipients(input) {
    const explicitAudience = normalizeUserIds(input.audienceUserIds, input.authorUserId);
    // Eingeschränkte Storys verwenden ausschließlich die beim Erstellen
    // gespeicherte Zielgruppe. Dadurch kann die Notification die Sichtbarkeit
    // einer Story niemals erweitern.
    if (input.visibilityType === "friendsOnly" ||
        input.visibilityType === "followersOnly" ||
        input.visibilityType === "privateList") {
        return explicitAudience;
    }
    // Öffentliche Storys bleiben öffentlich sichtbar, aber eine Aktivitäts-
    // Benachrichtigung wird bewusst nur bestätigten Freunden zugestellt.
    // So erzeugt eine öffentliche Story keinen globalen Notification-Spam.
    return loadAcceptedFriendIds(input.authorUserId);
}
async function loadAcceptedFriendIds(authorUserId) {
    const snapshot = await db
        .collection(friendshipsCollection)
        .where("participants", "array-contains", authorUserId)
        .get();
    const friendIds = new Set();
    for (const document of snapshot.docs) {
        const data = document.data() ?? {};
        if (cleanString(data.status) !== "accepted") {
            continue;
        }
        const requesterUserId = cleanString(data.requesterUserId);
        const addresseeUserId = cleanString(data.addresseeUserId);
        if (requesterUserId === authorUserId &&
            addresseeUserId &&
            addresseeUserId !== authorUserId) {
            friendIds.add(addresseeUserId);
            continue;
        }
        if (addresseeUserId === authorUserId &&
            requesterUserId &&
            requesterUserId !== authorUserId) {
            friendIds.add(requesterUserId);
        }
    }
    return Array.from(friendIds);
}
function normalizeVisibilityType(value) {
    switch (cleanString(value)) {
        case "friendsOnly":
            return "friendsOnly";
        case "followersOnly":
            return "followersOnly";
        case "privateList":
            return "privateList";
        case "public":
        default:
            return "public";
    }
}
function normalizeUserIds(values, excludedUserId) {
    const unique = new Set();
    for (const value of values) {
        const userId = cleanString(value);
        if (!userId || userId === excludedUserId) {
            continue;
        }
        unique.add(userId);
    }
    return Array.from(unique);
}
function readStringArray(value) {
    if (!Array.isArray(value)) {
        return [];
    }
    return value
        .map((entry) => cleanString(entry))
        .filter((entry) => entry.length > 0);
}
function safeActorLabel(actor) {
    return actor.displayName || actor.username || "Jemand";
}
function cleanString(value) {
    return typeof value === "string" ? value.trim() : "";
}
//# sourceMappingURL=story_push_triggers.js.map