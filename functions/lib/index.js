"use strict";
// Pfad: functions/src/index.ts
//
// Luma Passwort-Reset 2.0:
// - Brevo bleibt sichtbarer Absender.
// - Der Nutzer erhält keinen Firebase-Handler-Link mehr.
// - Der sichere Firebase-oobCode wird in eine Luma-URL übernommen.
// - Die Flutter-Web-App verarbeitet anschließend authAction=passwordReset.
//
// Vollständige Datei, aufgebaut auf der vom Nutzer bereitgestellten Version.
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkAccountEnforcementStatus = exports.liftAccountEnforcement = exports.reviewAccountEnforcementAppeal = exports.submitAccountEnforcementAppeal = exports.onFriendshipUpdated = exports.onFriendshipCreated = exports.onCommentLikeDeleted = exports.onCommentLikeCreated = exports.onCommentCreated = exports.onPostLikeDeleted = exports.onPostLikeCreated = exports.onPostCreated = exports.onStoryCreatedSendPush = exports.revokeRememberedLoginCredential = exports.exchangeRememberedLoginCredential = exports.registerRememberedLoginCredential = exports.createAgoraRtcToken = exports.disableAuthenticatorTotp = exports.verifyAuthenticatorLoginTotp = exports.getTwoFactorLoginRequirement = exports.verifyAuthenticatorTotp = exports.prepareAuthenticatorTotp = exports.revokeBackupCodes = exports.verifyBackupCode = exports.generateBackupCodes = exports.recordBackupCodesChanged = exports.recordTwoFactorChanged = exports.recordPhoneNumberChanged = exports.recordNewDeviceDetected = exports.revokeOtherSessions = exports.requestLumaEmailVerification = exports.requestLumaPasswordReset = exports.createFeedImagePreviewOnPostCreated = exports.notifyVerificationRequestStatus = exports.deleteCurrentUserAccount = exports.createAccountEnforcement = exports.lumaSecurityHealth = void 0;
const app_1 = require("firebase-admin/app");
const auth_1 = require("firebase-admin/auth");
const storage_1 = require("firebase-admin/storage");
const firestore_1 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const firebase_functions_1 = require("firebase-functions");
const v2_1 = require("firebase-functions/v2");
const params_1 = require("firebase-functions/params");
const https_1 = require("firebase-functions/v2/https");
const firestore_2 = require("firebase-functions/v2/firestore");
const crypto = __importStar(require("crypto"));
const sharp = require("sharp");
const agora_access_token_1 = require("agora-access-token");
(0, app_1.initializeApp)();
(0, v2_1.setGlobalOptions)({
    maxInstances: 3,
    region: "europe-west3",
    cpu: "gcf_gen1",
    concurrency: 1,
});
const db = (0, firestore_1.getFirestore)();
const agoraAppIdSecret = (0, params_1.defineSecret)("AGORA_APP_ID");
const agoraAppCertificateSecret = (0, params_1.defineSecret)("AGORA_APP_CERTIFICATE");
const brevoApiKeySecret = (0, params_1.defineSecret)("BREVO_API_KEY");
const agoraRtcTokenExpirySeconds = 60 * 60;
const callsCollection = "calls";
const feedImagesRoot = "feed_images";
const feedImageOriginalFileName = "image.jpg";
const feedImagePreviewFileName = "feed_preview.jpg";
const feedImagePreviewMaxDimension = 1200;
const feedImagePreviewJpegQuality = 78;
const usersCollection = "users";
const devicesCollection = "devices";
const settingsCollection = "settings";
const appSettingsDocument = "app";
const securityCollection = "security";
const backupCodesDocument = "backup_codes";
const codesCollection = "codes";
const totpDocument = "totp";
const securityEventsCollection = "security_events";
const securityAlertsCollection = "security_alerts";
const sessionPolicyDocument = "session_policy";
const authEmailRateLimitsCollection = "auth_email_rate_limits";
const passwordResetRateLimitWindowMs = 15 * 60 * 1000;
const passwordResetMaxRequestsPerWindow = 3;
const emailVerificationRateLimitWindowMs = 15 * 60 * 1000;
const emailVerificationMaxRequestsPerWindow = 3;
const lumaAuthDomain = "auth.luma-social.com";
const lumaPublicUrl = "https://luma-social.com";
const lumaPasswordResetContinueUrl = `https://${lumaAuthDomain}/?authAction=passwordReset`;
const lumaEmailVerificationContinueUrl = `https://${lumaAuthDomain}/?authAction=emailVerification`;
const lumaNoReplyEmail = "noreply@luma-social.com";
const lumaSupportEmail = "support@luma-social.com";
const lumaPrivacyEmail = "datenschutz@luma-social.com";
exports.lumaSecurityHealth = (0, https_1.onRequest)((_request, response) => {
    response.status(200).json({
        ok: true,
        service: "luma-security-functions",
        region: "europe-west3",
        timestamp: new Date().toISOString(),
    });
});
const accountEnforcementReasonCatalog = {
    "MINOR-001": {
        code: "MINOR-001",
        category: "Schutz Minderjähriger",
        publicTitle: "Schwerwiegender Verstoß im Bereich Schutz Minderjähriger",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten oder Kontaktaufnahmen, die nach unserer Prüfung gegen die Luma-Richtlinien zum Schutz von Kindern und Jugendlichen verstoßen oder ein erhebliches Sicherheitsrisiko in diesem Bereich darstellen.",
        disclosureLevel: "safetyCritical",
    },
    "MINOR-002": {
        code: "MINOR-002",
        category: "Schutz Minderjähriger",
        publicTitle: "Schwerwiegender Verstoß im Bereich Schutz Minderjähriger",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten oder Kontaktaufnahmen, die nach unserer Prüfung gegen die Luma-Richtlinien zum Schutz von Kindern und Jugendlichen verstoßen oder ein erhebliches Sicherheitsrisiko in diesem Bereich darstellen.",
        disclosureLevel: "safetyCritical",
    },
    "MINOR-003": {
        code: "MINOR-003",
        category: "Schutz Minderjähriger",
        publicTitle: "Schwerwiegender Verstoß im Bereich Schutz Minderjähriger",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Inhalten oder Aktivitäten, die nach unserer Prüfung ein schwerwiegendes Risiko für die Sicherheit und den Schutz Minderjähriger darstellen. Zum Schutz betroffener Personen und möglicher weiterer Maßnahmen werden keine detaillierten Einzelheiten angezeigt.",
        disclosureLevel: "safetyCritical",
    },
    "MINOR-004": {
        code: "MINOR-004",
        category: "Schutz Minderjähriger",
        publicTitle: "Schwerwiegender Verstoß im Bereich Schutz Minderjähriger",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten, die nach unserer Prüfung eine schwerwiegende Gefährdung Minderjähriger darstellen. Aus Sicherheitsgründen können wir hierzu keine weitergehenden Einzelheiten anzeigen.",
        disclosureLevel: "safetyCritical",
    },
    "SEX-001": {
        code: "SEX-001",
        category: "Sexuelle Ausbeutung & intime Inhalte",
        publicTitle: "Verstoß gegen unsere Richtlinien zum Schutz vor sexueller Ausbeutung",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Inhalten oder Verhaltensweisen, die gegen unsere Schutzregeln für intime Inhalte, Einwilligung und sexuelle Ausbeutung verstoßen.",
        disclosureLevel: "limited",
    },
    "SEX-002": {
        code: "SEX-002",
        category: "Sexuelle Ausbeutung & intime Inhalte",
        publicTitle: "Schwerwiegender Verstoß gegen unsere Schutzrichtlinien",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten, die nach unserer Prüfung gegen unsere Richtlinien zum Schutz vor Erpressung, Zwang oder sexueller Ausbeutung verstoßen.",
        disclosureLevel: "limited",
    },
    "CYBER-001": {
        code: "CYBER-001",
        category: "Cyberkriminalität & Kontosicherheit",
        publicTitle: "Schwerwiegender Verstoß gegen unsere Sicherheitsrichtlinien",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten, die nach unserer Prüfung die Sicherheit von Konten, Zugangsdaten oder anderen Personen gefährden können.",
        disclosureLevel: "limited",
    },
    "CYBER-002": {
        code: "CYBER-002",
        category: "Cyberkriminalität & Kontosicherheit",
        publicTitle: "Schwerwiegender Verstoß gegen unsere Sicherheitsrichtlinien",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten, die nach unserer Prüfung die technische Sicherheit von Luma oder anderen Personen gefährden können.",
        disclosureLevel: "limited",
    },
    "CYBER-003": {
        code: "CYBER-003",
        category: "Cyberkriminalität & Kontosicherheit",
        publicTitle: "Schwerwiegender Verstoß gegen unsere Sicherheitsrichtlinien",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit auffälligen oder unzulässigen Aktivitäten im Bereich Konto- und Zugriffssicherheit.",
        disclosureLevel: "safetyCritical",
    },
    "FRAUD-001": {
        code: "FRAUD-001",
        category: "Betrug & Täuschung",
        publicTitle: "Betrügerisches oder irreführendes Verhalten",
        publicDescription: "Die Maßnahme wurde aufgrund von Aktivitäten verhängt, die nach unserer Prüfung gegen unsere Regeln zu Betrug, Täuschung oder missbräuchlichen finanziellen Handlungen verstoßen.",
        disclosureLevel: "standard",
    },
    "FRAUD-002": {
        code: "FRAUD-002",
        category: "Betrug & Täuschung",
        publicTitle: "Betrügerisches oder irreführendes Verhalten",
        publicDescription: "Die Maßnahme wurde aufgrund von Aktivitäten verhängt, die nach unserer Prüfung gegen unsere Regeln zu Betrug, Täuschung oder irreführenden Angeboten verstoßen.",
        disclosureLevel: "standard",
    },
    "IDENT-001": {
        code: "IDENT-001",
        category: "Identität & Authentizität",
        publicTitle: "Missbrauch oder Täuschung hinsichtlich einer Identität",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit einer Nutzung von Luma, die nach unserer Prüfung gegen unsere Regeln zu Identität, Authentizität oder irreführender Darstellung verstößt.",
        disclosureLevel: "standard",
    },
    "VIOLENCE-001": {
        code: "VIOLENCE-001",
        category: "Gewalt & Gefährdung",
        publicTitle: "Verstoß gegen unsere Richtlinien zu Gewalt und Gefährdung",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Inhalten oder Verhalten, die nach unserer Prüfung eine erhebliche Gefahr für die Sicherheit anderer darstellen oder Gewalt androhen.",
        disclosureLevel: "safetyCritical",
    },
    "VIOLENCE-002": {
        code: "VIOLENCE-002",
        category: "Gewalt & Gefährdung",
        publicTitle: "Verstoß gegen unsere Richtlinien zu Gewalt und Gefährdung",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Inhalten oder Aktivitäten, die nach unserer Prüfung gegen unsere Regeln zu Gewalt und schwerwiegender Gefährdung verstoßen.",
        disclosureLevel: "limited",
    },
    "HARASS-001": {
        code: "HARASS-001",
        category: "Belästigung & Stalking",
        publicTitle: "Belästigung oder missbräuchliches Verhalten",
        publicDescription: "Die Maßnahme wurde aufgrund wiederholter oder schwerwiegender Verhaltensweisen verhängt, die gegen unsere Regeln zum Schutz vor Belästigung und unerwünschtem Kontakt verstoßen.",
        disclosureLevel: "standard",
    },
    "HARASS-002": {
        code: "HARASS-002",
        category: "Belästigung & Stalking",
        publicTitle: "Schwerwiegender Verstoß gegen unsere Schutzrichtlinien",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit wiederholtem oder schwerwiegendem Verhalten, das nach unserer Prüfung die Sicherheit oder Privatsphäre anderer beeinträchtigt.",
        disclosureLevel: "limited",
    },
    "HATE-001": {
        code: "HATE-001",
        category: "Hass & Diskriminierung",
        publicTitle: "Verstoß gegen unsere Richtlinien zu Hass und diskriminierendem Verhalten",
        publicDescription: "Die Maßnahme wurde aufgrund von Inhalten oder Verhalten verhängt, die nach unserer Prüfung gegen unsere Regeln zum Schutz vor Hass und diskriminierenden Angriffen verstoßen.",
        disclosureLevel: "standard",
    },
    "PRIV-001": {
        code: "PRIV-001",
        category: "Privatsphäre & persönliche Daten",
        publicTitle: "Verstoß gegen unsere Richtlinien zu Privatsphäre und persönlichen Daten",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit der Veröffentlichung oder Nutzung persönlicher Informationen, die nach unserer Prüfung gegen unsere Schutz- und Privatsphärenregeln verstößt.",
        disclosureLevel: "standard",
    },
    "SPAM-001": {
        code: "SPAM-001",
        category: "Spam & Manipulation",
        publicTitle: "Spam oder manipulatives Verhalten",
        publicDescription: "Die Maßnahme wurde aufgrund von Aktivitäten verhängt, die nach unserer Prüfung gegen unsere Regeln zu Spam, massenhafter Kontaktaufnahme oder manipulativer Nutzung verstoßen.",
        disclosureLevel: "standard",
    },
    "SPAM-002": {
        code: "SPAM-002",
        category: "Spam & Manipulation",
        publicTitle: "Spam oder manipulatives Verhalten",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten, die nach unserer Prüfung die Integrität von Interaktionen oder Reichweite auf Luma manipulieren.",
        disclosureLevel: "standard",
    },
    "ABUSE-001": {
        code: "ABUSE-001",
        category: "Missbrauch von Luma",
        publicTitle: "Missbrauch von Luma oder seinen Funktionen",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit einer Nutzung von Luma, die nach unserer Prüfung Schutz-, Sicherheits- oder Integritätsmechanismen missbraucht oder gezielt umgeht.",
        disclosureLevel: "limited",
    },
    "EVASION-001": {
        code: "EVASION-001",
        category: "Umgehung von Maßnahmen",
        publicTitle: "Umgehung einer bestehenden Luma-Maßnahme",
        publicDescription: "Die Maßnahme wurde verhängt, weil nach unserer Prüfung eine bestehende Einschränkung oder Kontomaßnahme umgangen wurde.",
        disclosureLevel: "standard",
    },
    "ILLEGAL-001": {
        code: "ILLEGAL-001",
        category: "Schwerwiegende rechtswidrige Aktivitäten",
        publicTitle: "Schwerwiegender Sicherheits- oder Richtlinienverstoß",
        publicDescription: "Die Maßnahme steht im Zusammenhang mit Aktivitäten, die nach unserer Prüfung einen schwerwiegenden Verstoß gegen unsere Sicherheits- oder Community-Richtlinien darstellen. Zum Schutz betroffener Personen und möglicher weiterer Maßnahmen können Einzelheiten eingeschränkt sein.",
        disclosureLevel: "safetyCritical",
    },
    "COMMUNITY-001": {
        code: "COMMUNITY-001",
        category: "Sonstiger schwerwiegender Richtlinienverstoß",
        publicTitle: "Schwerwiegender Verstoß gegen die Luma Community-Richtlinien",
        publicDescription: "Die Maßnahme wurde aufgrund eines erheblichen oder wiederholten Verstoßes gegen die Luma Community-Richtlinien verhängt.",
        disclosureLevel: "standard",
    },
};
/**
 * Zentrale serverseitige Kontomaßnahme.
 *
 * Der Client darf nur action, reasonCode, Dauer und interne Notiz
 * anfragen. Nutzertexte, Fallnummern, Audit-Daten und der tatsächliche
 * Enforcement-State werden ausschließlich auf dem Server erzeugt.
 */
exports.createAccountEnforcement = (0, https_1.onCall)({
    secrets: [brevoApiKeySecret],
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (request) => {
    const actor = await requireEnforcementAdminActor({
        userId: request.auth?.uid,
        token: request.auth?.token,
    });
    const targetUserId = cleanString(request.data?.targetUserId);
    const action = normalizeAccountEnforcementAction(request.data?.action);
    const reasonCode = cleanString(request.data?.reasonCode).toUpperCase();
    const internalNote = cleanString(request.data?.internalNote);
    const requestedDurationHours = readPositiveNumber(request.data?.durationHours);
    if (!targetUserId) {
        throw new https_1.HttpsError("invalid-argument", "targetUserId fehlt.");
    }
    if (targetUserId === actor.userId) {
        throw new https_1.HttpsError("failed-precondition", "Du kannst keine Kontomaßnahme gegen dein eigenes Administrationskonto verhängen.");
    }
    requireEnforcementActionPermission(actor.role, action);
    const reason = accountEnforcementReasonCatalog[reasonCode];
    if (!reason) {
        throw new https_1.HttpsError("invalid-argument", "Dieser Sperrgrund ist nicht freigegeben.");
    }
    if (internalNote.length > 4000) {
        throw new https_1.HttpsError("invalid-argument", "Die interne Begründung ist zu lang.");
    }
    if (action !== "warning" && internalNote.length < 10) {
        throw new https_1.HttpsError("invalid-argument", "Für eine Kontosperre ist eine nachvollziehbare interne Dokumentation erforderlich.");
    }
    const durationHours = resolveEnforcementDurationHours({
        action,
        requestedDurationHours,
    });
    const [targetUserRecord, targetProfileSnapshot, targetAdminSnapshot] = await Promise.all([
        (0, auth_1.getAuth)().getUser(targetUserId).catch((error) => {
            if (isFirebaseUserNotFoundError(error)) {
                throw new https_1.HttpsError("not-found", "Das ausgewählte Luma-Konto existiert nicht mehr.");
            }
            throw error;
        }),
        db.collection(usersCollection).doc(targetUserId).get(),
        db.collection("admins").doc(targetUserId).get(),
    ]);
    protectAdministrativeTarget({
        actorRole: actor.role,
        targetAdminData: targetAdminSnapshot.exists
            ? targetAdminSnapshot.data() ?? {}
            : null,
        targetCustomClaims: targetUserRecord.customClaims,
    });
    const now = new Date();
    const expiresAt = durationHours === null
        ? null
        : new Date(now.getTime() + durationHours * 60 * 60 * 1000);
    const caseReference = db.collection("moderationCases").doc();
    const enforcementReference = db.collection("accountEnforcements").doc();
    const stateReference = db
        .collection("accountEnforcementStates")
        .doc(targetUserId);
    const auditReference = db.collection("adminAuditLogs").doc();
    const caseNumber = createModerationCaseNumber(now);
    const enforcementId = enforcementReference.id;
    const appealAccessToken = crypto.randomBytes(32).toString("hex");
    const appealAccessTokenHash = sha256Hex(appealAccessToken);
    const previousStateSnapshot = await stateReference.get();
    const previousState = previousStateSnapshot.exists
        ? previousStateSnapshot.data() ?? null
        : null;
    const enforcementType = accountEnforcementStateType(action);
    const isBlockingAction = action !== "warning";
    const batch = db.batch();
    batch.set(caseReference, {
        id: caseReference.id,
        caseNumber,
        source: "adminDirect",
        targetUserId,
        targetDisplayName: cleanString(targetProfileSnapshot.data()?.displayName) ||
            cleanString(targetUserRecord.displayName) ||
            "Luma-Mitglied",
        status: "decided",
        category: reason.category,
        reasonCode: reason.code,
        publicReasonTitle: reason.publicTitle,
        publicReasonDescription: reason.publicDescription,
        disclosureLevel: reason.disclosureLevel,
        internalNote,
        decisionAction: action,
        enforcementId,
        createdByAdminId: actor.userId,
        createdByAdminDisplayName: actor.displayName,
        createdByAdminRole: actor.role,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        decidedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        schemaVersion: 1,
    });
    const previousEnforcementId = previousState === null
        ? ""
        : cleanString(previousState.enforcementId);
    if (previousEnforcementId && isBlockingAction) {
        batch.set(db.collection("accountEnforcements").doc(previousEnforcementId), {
            isActive: false,
            status: "superseded",
            supersededByEnforcementId: enforcementId,
            supersededAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    batch.set(enforcementReference, {
        id: enforcementId,
        caseId: caseReference.id,
        caseNumber,
        userId: targetUserId,
        action,
        type: enforcementType,
        status: isBlockingAction ? "active" : "completed",
        isActive: isBlockingAction,
        reasonCode: reason.code,
        category: reason.category,
        publicReasonTitle: reason.publicTitle,
        publicReasonDescription: reason.publicDescription,
        disclosureLevel: reason.disclosureLevel,
        internalNote,
        appealAccessTokenHash,
        appealAllowed: isBlockingAction,
        startsAt: now,
        expiresAt,
        createdByAdminId: actor.userId,
        createdByAdminDisplayName: actor.displayName,
        createdByAdminRole: actor.role,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        schemaVersion: 1,
    });
    if (isBlockingAction) {
        batch.set(stateReference, {
            userId: targetUserId,
            enforcementId,
            caseId: caseReference.id,
            caseNumber,
            type: enforcementType,
            action,
            isActive: true,
            reasonCode: reason.code,
            publicReasonTitle: reason.publicTitle,
            publicReasonDescription: reason.publicDescription,
            disclosureLevel: reason.disclosureLevel,
            appealAccessToken,
            appealId: "",
            appealTicketNumber: "",
            appealStatus: "",
            startsAt: now,
            expiresAt,
            createdByAdminId: actor.userId,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            schemaVersion: 1,
        }, { merge: false });
    }
    batch.set(auditReference, {
        id: auditReference.id,
        actorAdminId: actor.userId,
        actorDisplayName: actor.displayName,
        actorRole: actor.role,
        targetUserId,
        action: "accountEnforcementCreated",
        enforcementAction: action,
        enforcementId,
        caseId: caseReference.id,
        caseNumber,
        reasonCode: reason.code,
        previousState: sanitizePreviousEnforcementState(previousState),
        newState: isBlockingAction
            ? {
                type: enforcementType,
                isActive: true,
                expiresAt,
                caseNumber,
            }
            : {
                type: "warning",
                isActive: false,
                expiresAt: null,
                caseNumber,
            },
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        schemaVersion: 1,
    });
    await batch.commit();
    if (isBlockingAction) {
        try {
            await (0, auth_1.getAuth)().revokeRefreshTokens(targetUserId);
        }
        catch (error) {
            firebase_functions_1.logger.error("ACCOUNT_ENFORCEMENT_TOKEN_REVOCATION_FAILED", {
                targetUserId,
                caseNumber,
                enforcementId,
                error,
            });
        }
    }
    const recipientEmail = normalizeEmailAddress(targetUserRecord.email);
    const recipientName = cleanString(targetProfileSnapshot.data()?.displayName) ||
        cleanString(targetUserRecord.displayName) ||
        "Luma-Mitglied";
    const emailSent = await sendAccountEnforcementEmailSafely({
        targetUserId,
        recipientEmail,
        recipientName,
        action,
        publicReasonTitle: reason.publicTitle,
        publicReasonDescription: reason.publicDescription,
        caseNumber,
        expiresAt,
    });
    firebase_functions_1.logger.info("ACCOUNT_ENFORCEMENT_CREATED", {
        actorUserId: actor.userId,
        actorRole: actor.role,
        targetUserId,
        action,
        reasonCode: reason.code,
        caseNumber,
        enforcementId,
        emailSent,
    });
    return {
        success: true,
        caseNumber,
        enforcementId,
        emailSent,
    };
});
async function requireEnforcementAdminActor(input) {
    const userId = requireAuthenticatedUserId(input.userId);
    const token = input.token ?? {};
    if (token.isActive === false) {
        throw new https_1.HttpsError("permission-denied", "Dieser Adminzugang ist deaktiviert.");
    }
    const claimRole = cleanString(token.role);
    let role = null;
    if (token.superAdmin === true || claimRole === "superAdmin") {
        role = "superAdmin";
    }
    else if (token.admin === true || claimRole === "admin") {
        role = "admin";
    }
    else if (token.moderator === true || claimRole === "moderator") {
        role = "moderator";
    }
    let displayName = cleanString(token.displayName);
    if (role === null) {
        const adminSnapshot = await db.collection("admins").doc(userId).get();
        const data = adminSnapshot.data() ?? {};
        if (!adminSnapshot.exists || data.isActive !== true) {
            throw new https_1.HttpsError("permission-denied", "Du besitzt keine aktive Berechtigung für die Luma-Administration.");
        }
        const storedRole = cleanString(data.role);
        if (storedRole !== "superAdmin" &&
            storedRole !== "admin" &&
            storedRole !== "moderator") {
            throw new https_1.HttpsError("permission-denied", "Deine Adminrolle darf keine Kontomaßnahmen verwalten.");
        }
        role = storedRole;
        displayName = cleanString(data.displayName);
    }
    if (!displayName) {
        try {
            const userRecord = await (0, auth_1.getAuth)().getUser(userId);
            displayName = cleanString(userRecord.displayName);
        }
        catch (_) {
            displayName = "Luma Administration";
        }
    }
    return {
        userId,
        displayName: displayName || "Luma Administration",
        role,
    };
}
function normalizeAccountEnforcementAction(value) {
    const action = cleanString(value);
    if (action === "warning" ||
        action === "safetyHold" ||
        action === "temporarySuspension" ||
        action === "permanentSuspension") {
        return action;
    }
    throw new https_1.HttpsError("invalid-argument", "Ungültige Kontomaßnahme.");
}
function requireEnforcementActionPermission(role, action) {
    if (role === "superAdmin" || role === "admin") {
        return;
    }
    if (role === "moderator" && action === "warning") {
        return;
    }
    throw new https_1.HttpsError("permission-denied", "Deine Adminrolle darf diese Kontomaßnahme nicht verhängen.");
}
function protectAdministrativeTarget(input) {
    const data = input.targetAdminData;
    const claims = input.targetCustomClaims ?? {};
    const claimRole = cleanString(claims.role);
    const claimSuperAdmin = claims.superAdmin === true || claimRole === "superAdmin";
    const claimAdmin = claims.admin === true || claimRole === "admin";
    const claimModerator = claims.moderator === true || claimRole === "moderator";
    const storedRole = data?.isActive === true ? cleanString(data.role) : "";
    const targetRole = claimSuperAdmin
        ? "superAdmin"
        : claimAdmin
            ? "admin"
            : claimModerator
                ? "moderator"
                : storedRole;
    if (!targetRole)
        return;
    if (targetRole === "superAdmin") {
        throw new https_1.HttpsError("failed-precondition", "Aktive Super-Admin-Konten können nicht über die normale Nutzeradministration gesperrt werden.");
    }
    if ((targetRole === "admin" || targetRole === "moderator") &&
        input.actorRole !== "superAdmin") {
        throw new https_1.HttpsError("permission-denied", "Nur ein Super Admin kann eine Kontomaßnahme gegen ein anderes Administrationskonto verhängen.");
    }
}
function resolveEnforcementDurationHours(input) {
    switch (input.action) {
        case "warning":
        case "permanentSuspension":
            return null;
        case "safetyHold":
            return 72;
        case "temporarySuspension": {
            const allowed = new Set([1, 24, 72, 168, 720]);
            if (!allowed.has(input.requestedDurationHours)) {
                throw new https_1.HttpsError("invalid-argument", "Diese Sperrdauer ist nicht freigegeben.");
            }
            return input.requestedDurationHours;
        }
    }
}
function accountEnforcementStateType(action) {
    switch (action) {
        case "warning":
            return "warning";
        case "safetyHold":
            return "safetyHold";
        case "temporarySuspension":
            return "temporarySuspension";
        case "permanentSuspension":
            return "permanentSuspension";
    }
}
function createModerationCaseNumber(now) {
    const year = now.getUTCFullYear();
    const randomPart = crypto.randomBytes(5).toString("hex").toUpperCase();
    return `LUMA-${year}-${randomPart}`;
}
function sanitizePreviousEnforcementState(value) {
    if (!value)
        return null;
    return {
        enforcementId: cleanString(value.enforcementId) || null,
        caseNumber: cleanString(value.caseNumber) || null,
        type: cleanString(value.type) || null,
        isActive: value.isActive === true,
        reasonCode: cleanString(value.reasonCode) || null,
        expiresAt: value.expiresAt ?? null,
    };
}
async function sendAccountEnforcementEmailSafely(input) {
    if (!isValidEmailAddress(input.recipientEmail)) {
        firebase_functions_1.logger.warn("ACCOUNT_ENFORCEMENT_EMAIL_SKIPPED", {
            targetUserId: input.targetUserId,
            caseNumber: input.caseNumber,
            reason: "missing-or-invalid-email",
        });
        return false;
    }
    const expiresAtLabel = input.expiresAt === null
        ? null
        : new Intl.DateTimeFormat("de-DE", {
            dateStyle: "long",
            timeStyle: "short",
            timeZone: "Europe/Berlin",
        }).format(input.expiresAt);
    try {
        await sendBrevoTransactionalEmail({
            apiKey: brevoApiKeySecret.value(),
            recipientEmail: input.recipientEmail,
            recipientName: input.recipientName,
            senderName: "Luma Safety",
            subject: "Wichtige Information zu deinem Luma-Konto",
            htmlContent: createAccountEnforcementEmailHtml({
                displayName: input.recipientName,
                action: input.action,
                publicReasonTitle: input.publicReasonTitle,
                publicReasonDescription: input.publicReasonDescription,
                caseNumber: input.caseNumber,
                expiresAtLabel,
            }),
            textContent: createAccountEnforcementEmailText({
                displayName: input.recipientName,
                action: input.action,
                publicReasonTitle: input.publicReasonTitle,
                publicReasonDescription: input.publicReasonDescription,
                caseNumber: input.caseNumber,
                expiresAtLabel,
            }),
            tags: ["luma-safety", "account-enforcement"],
            replyToEmail: lumaSupportEmail,
            replyToName: "Luma Support",
        });
        return true;
    }
    catch (error) {
        firebase_functions_1.logger.error("ACCOUNT_ENFORCEMENT_EMAIL_FAILED", {
            targetUserId: input.targetUserId,
            caseNumber: input.caseNumber,
            emailHash: sha256Hex(input.recipientEmail),
            error,
        });
        return false;
    }
}
function enforcementActionLabel(action) {
    switch (action) {
        case "warning":
            return "Verwarnung";
        case "safetyHold":
            return "Sicherheitsprüfung";
        case "temporarySuspension":
            return "Vorübergehende Kontosperre";
        case "permanentSuspension":
            return "Dauerhafte Kontosperre";
    }
}
function createAccountEnforcementEmailHtml(input) {
    const displayName = escapeHtml(input.displayName);
    const actionLabel = escapeHtml(enforcementActionLabel(input.action));
    const reasonTitle = escapeHtml(input.publicReasonTitle);
    const reasonDescription = escapeHtml(input.publicReasonDescription);
    const caseNumber = escapeHtml(input.caseNumber);
    const expires = input.expiresAtLabel
        ? `<p style="margin:8px 0 0"><strong>Sperre bis:</strong> ${escapeHtml(input.expiresAtLabel)}</p>`
        : "";
    return `<!doctype html>
<html lang="de">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#1f2937">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f5f7;padding:32px 12px">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:620px;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #e5e7eb">
        <tr><td style="padding:28px 32px 18px;font-size:26px;font-weight:800">Luma</td></tr>
        <tr><td style="padding:0 32px 32px">
          <h1 style="font-size:24px;line-height:1.25;margin:0 0 18px">Wichtige Information zu deinem Luma-Konto</h1>
          <p style="line-height:1.6">Hallo ${displayName},</p>
          <p style="line-height:1.6">wir informieren dich darüber, dass nach einer Überprüfung eine Kontomaßnahme für dein Luma-Konto verhängt wurde.</p>
          <div style="background:#f8fafc;border:1px solid #e5e7eb;border-radius:14px;padding:18px;margin:22px 0">
            <p style="margin:0 0 10px"><strong>Maßnahme:</strong> ${actionLabel}</p>
            <p style="margin:0 0 8px"><strong>Grund:</strong> ${reasonTitle}</p>
            <p style="margin:0;line-height:1.55">${reasonDescription}</p>
            ${expires}
            <p style="margin:8px 0 0"><strong>Fallnummer:</strong> ${caseNumber}</p>
          </div>
          <h2 style="font-size:18px;margin:24px 0 10px">Du hältst die Entscheidung für falsch?</h2>
          <p style="line-height:1.6">Du kannst eine Überprüfung der Entscheidung beantragen. Wende dich unter Angabe deiner Fallnummer an <strong>${escapeHtml(lumaSupportEmail)}</strong>.</p>
          <p style="line-height:1.6">Während einer Überprüfung bleibt die bestehende Maßnahme grundsätzlich aktiv, sofern sie nicht vorher geändert oder aufgehoben wird.</p>
          <p style="margin-top:28px;line-height:1.6">Viele Grüße<br><strong>Luma Safety</strong></p>
          <p style="font-size:12px;color:#6b7280;line-height:1.5">Diese Nachricht wurde automatisch versendet. Bitte antworte nicht direkt auf diese E-Mail.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}
function createAccountEnforcementEmailText(input) {
    const lines = [
        "Luma",
        "",
        "Wichtige Information zu deinem Luma-Konto",
        "",
        `Hallo ${input.displayName},`,
        "",
        "nach einer Überprüfung wurde eine Kontomaßnahme für dein Luma-Konto verhängt.",
        "",
        `Maßnahme: ${enforcementActionLabel(input.action)}`,
        `Grund: ${input.publicReasonTitle}`,
        input.publicReasonDescription,
    ];
    if (input.expiresAtLabel) {
        lines.push(`Sperre bis: ${input.expiresAtLabel}`);
    }
    lines.push(`Fallnummer: ${input.caseNumber}`, "", "Du hältst die Entscheidung für falsch?", `Du kannst unter Angabe deiner Fallnummer eine Überprüfung über ${lumaSupportEmail} beantragen.`, "", "Viele Grüße", "Luma Safety", "", "Diese Nachricht wurde automatisch versendet. Bitte antworte nicht direkt auf diese E-Mail.");
    return lines.join("\n");
}
/**
 * Löscht das aktuell angemeldete Luma-Konto serverseitig und UID-basiert.
 *
 * Sicherheitsprinzipien:
 * - Die aufrufende Firebase-Sitzung muss frisch bestätigt worden sein.
 * - Nutzerbezogene Kerninhalte außerhalb von users/{uid} werden zuerst
 *   serverseitig entfernt.
 * - Messenger-Unterhaltungen anderer Teilnehmer bleiben erhalten, die
 *   gespeicherte Identität des gelöschten Nutzers wird jedoch neutralisiert.
 * - Das komplette users/{uid}-Dokument inklusive Unterkollektionen wird
 *   rekursiv entfernt.
 * - Firebase Authentication wird ganz am Ende entfernt.
 *
 * Hinweis:
 * Moderations-/Meldedaten werden hier bewusst nicht pauschal gelöscht.
 * Sie können für Sicherheits-, Missbrauchs- oder Rechtszwecke erforderlich
 * sein und müssen separat nach ihrer zulässigen Aufbewahrungslogik behandelt
 * werden.
 */
exports.deleteCurrentUserAccount = (0, https_1.onCall)({
    secrets: [brevoApiKeySecret],
    timeoutSeconds: 120,
    memory: "512MiB",
}, async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    requireRecentAccountDeletionAuthentication(request.auth?.token?.auth_time);
    let deletionEmail = "";
    let deletionDisplayName = "Luma-Mitglied";
    try {
        const userRecord = await (0, auth_1.getAuth)().getUser(userId);
        deletionEmail = normalizeEmailAddress(userRecord.email);
        deletionDisplayName =
            cleanString(userRecord.displayName) || "Luma-Mitglied";
    }
    catch (error) {
        if (isFirebaseUserNotFoundError(error)) {
            throw new https_1.HttpsError("not-found", "Dieses Luma-Konto existiert nicht mehr.");
        }
        firebase_functions_1.logger.error("ACCOUNT_DELETE_AUTH_LOOKUP_FAILED", {
            userId,
            error,
        });
        throw new https_1.HttpsError("unavailable", "Das Konto konnte momentan nicht geprüft werden.");
    }
    try {
        firebase_functions_1.logger.info("ACCOUNT_DELETE_STARTED", {
            userId,
        });
        // 1. Kommunikationsmetadaten anderer Teilnehmer anonymisieren.
        await anonymizeDeletedUserInConversations(userId);
        // 2. Nutzerbezogene Kernobjekte außerhalb von users/{uid} entfernen.
        //
        // Diese Collections liegen nicht unter dem User-Dokument und würden
        // durch db.recursiveDelete(users/{uid}) sonst erhalten bleiben.
        await deleteMatchingDocumentsRecursively("feed_posts", "userId", "==", userId);
        await deleteMatchingDocumentsRecursively("stories", "authorId", "==", userId);
        await deleteFriendshipsForDeletedUser(userId);
        await deleteMatchingDocumentsRecursively("profile_relationships", "participantUserIds", "array-contains", userId);
        await deleteMatchingDocumentsRecursively("blocks", "blockerUserId", "==", userId);
        await deleteMatchingDocumentsRecursively("blocks", "blockedUserId", "==", userId);
        await deleteMatchingDocumentsRecursively("messenger_blocks", "participantIds", "array-contains", userId);
        await deleteMatchingDocumentsRecursively("calls", "participantIds", "array-contains", userId);
        // Verifikationsanträge können Identitätsangaben und Dokument-URLs
        // enthalten und werden deshalb bei der normalen Kontolöschung
        // ebenfalls entfernt.
        await deleteMatchingDocumentsRecursively("verification_requests", "userId", "==", userId);
        // 3. Das komplette User-Dokument mit allen Subcollections entfernen.
        // Dazu gehören u. a. Profil, Einstellungen, Notification-Tokens,
        // Geräte-/Sicherheitsdaten und Legal-Consent-Unterlagen unter users/{uid}.
        const userReference = db
            .collection(usersCollection)
            .doc(userId);
        await db.recursiveDelete(userReference);
        // 4. Firebase Auth ganz am Ende entfernen.
        await (0, auth_1.getAuth)().deleteUser(userId);
        // 5. Erst NACH der bestätigten Auth-Löschung wird die Bestätigungs-Mail
        // versendet. Dadurch kann niemals eine Löschbestätigung verschickt werden,
        // obwohl das Firebase-Konto noch existiert.
        const confirmationEmailSent = await sendAccountDeletionConfirmationEmailSafely({
            userId,
            recipientEmail: deletionEmail,
            displayName: deletionDisplayName,
        });
        firebase_functions_1.logger.info("ACCOUNT_DELETE_COMPLETED", {
            userId,
            confirmationEmailSent,
        });
        return {
            success: true,
            accountDeleted: true,
            profileDeleted: true,
            userContentDeleted: true,
            conversationsAnonymized: true,
            confirmationEmailSent,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error("ACCOUNT_DELETE_FAILED", {
            userId,
            error,
        });
        throw new https_1.HttpsError("internal", "Das Luma-Konto konnte nicht vollständig gelöscht werden.");
    }
});
function requireRecentAccountDeletionAuthentication(rawAuthTime) {
    const authTimeSeconds = typeof rawAuthTime === "number" && Number.isFinite(rawAuthTime)
        ? rawAuthTime
        : Number.parseInt(cleanString(rawAuthTime), 10);
    if (!Number.isFinite(authTimeSeconds)) {
        throw new https_1.HttpsError("failed-precondition", "Bitte bestätige deine Identität erneut.");
    }
    const nowSeconds = Math.floor(Date.now() / 1000);
    const maxAgeSeconds = 10 * 60;
    const ageSeconds = Math.max(0, nowSeconds - authTimeSeconds);
    if (ageSeconds > maxAgeSeconds) {
        throw new https_1.HttpsError("failed-precondition", "Bitte bestätige deine Identität erneut.");
    }
}
async function deleteMatchingDocumentsRecursively(collectionName, fieldPath, operator, userId) {
    const snapshot = await db
        .collection(collectionName)
        .where(fieldPath, operator, userId)
        .get();
    if (snapshot.empty) {
        return;
    }
    firebase_functions_1.logger.info("ACCOUNT_DELETE_MATCHING_DOCUMENTS", {
        userId,
        collectionName,
        fieldPath,
        count: snapshot.size,
    });
    // Absichtlich nacheinander: recursiveDelete kann pro Dokument weitere
    // Unterkollektionen entfernen. Das begrenzt Lastspitzen und macht Fehler
    // eindeutig dem betroffenen Dokument zuordenbar.
    for (const document of snapshot.docs) {
        await db.recursiveDelete(document.ref);
    }
}
async function deleteFriendshipsForDeletedUser(userId) {
    const snapshot = await db
        .collection("friendships")
        .where("participants", "array-contains", userId)
        .get();
    if (snapshot.empty) {
        return;
    }
    for (const document of snapshot.docs) {
        const data = document.data() ?? {};
        const participantIds = readStringArray(data.participants);
        // Spiegel auf den Profilen der anderen Beteiligten entfernen.
        // Der eigene Spiegel verschwindet später ohnehin zusammen mit users/{uid}.
        for (const participantId of participantIds) {
            if (!participantId || participantId === userId) {
                continue;
            }
            await db
                .collection(usersCollection)
                .doc(participantId)
                .collection("friends")
                .doc(userId)
                .delete()
                .catch((error) => {
                firebase_functions_1.logger.warn("ACCOUNT_DELETE_FRIEND_MIRROR_DELETE_FAILED", {
                    userId,
                    participantId,
                    friendshipId: document.id,
                    error,
                });
            });
        }
        await db.recursiveDelete(document.ref);
    }
}
async function anonymizeDeletedUserInConversations(userId) {
    const snapshot = await db
        .collection("conversations")
        .where("participantIds", "array-contains", userId)
        .get();
    if (snapshot.empty) {
        return;
    }
    const chunkSize = 400;
    for (let offset = 0; offset < snapshot.docs.length; offset += chunkSize) {
        const batch = db.batch();
        const documents = snapshot.docs.slice(offset, offset + chunkSize);
        for (const document of documents) {
            const data = document.data() ?? {};
            const rawParticipants = Array.isArray(data.participants)
                ? data.participants
                : [];
            const participants = rawParticipants.map((value) => {
                if (!value || typeof value !== "object" || Array.isArray(value)) {
                    return value;
                }
                const participant = value;
                if (cleanString(participant.userId) !== userId) {
                    return participant;
                }
                return {
                    ...participant,
                    userId,
                    displayName: "Gelöschter Nutzer",
                    username: "",
                    avatarUrl: "",
                    isOnline: false,
                    isBlueVerified: false,
                    isGreyVerified: false,
                    verificationState: "none",
                };
            });
            const conversationType = cleanString(data.conversationType);
            const isPageSupportConversation = conversationType === "pageSupport";
            const unreadCounts = readNumberMap(data.unreadCountsByUserId);
            delete unreadCounts[userId];
            const identityReset = {
                participants,
                unreadCountsByUserId: unreadCounts,
                pinnedUserIds: withoutUserId(data.pinnedUserIds, userId),
                mutedUserIds: withoutUserId(data.mutedUserIds, userId),
                archivedUserIds: withoutUserId(data.archivedUserIds, userId),
                deletedForUserIds: withoutUserId(data.deletedForUserIds, userId),
                deletedParticipantUserIds: firestore_1.FieldValue.arrayUnion(userId),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            };
            if (isPageSupportConversation) {
                identityReset.pageName = "Luma Nutzer";
                identityReset.pageUsername = "";
                identityReset.pageAvatarUrl = "";
                identityReset.pageIsBlueVerified = false;
                identityReset.pageIsGreyVerified = false;
            }
            batch.set(document.ref, identityReset, { merge: true });
        }
        await batch.commit();
    }
}
function withoutUserId(value, userId) {
    return readStringArray(value).filter((entry) => entry !== userId);
}
function readNumberMap(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        return {};
    }
    const output = {};
    for (const [key, rawValue] of Object.entries(value)) {
        if (typeof rawValue !== "number" || !Number.isFinite(rawValue)) {
            continue;
        }
        output[key] = Math.max(0, Math.trunc(rawValue));
    }
    return output;
}
/**
 * Erstellt bei jedem relevanten Verifikationsstatus eine dauerhafte
 * In-App-Benachrichtigung und einen anklickbaren Push.
 *
 * Ablehnungs- und Entzugsgründe werden absichtlich nicht in den Push
 * geschrieben. Sie sind erst nach Anmeldung in der Detailansicht sichtbar.
 */
exports.notifyVerificationRequestStatus = (0, firestore_2.onDocumentWritten)({
    document: "verification_requests/{requestId}",
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (event) => {
    const after = event.data?.after;
    const before = event.data?.before;
    const requestId = cleanString(event.params.requestId);
    if (!after?.exists || !requestId) {
        return;
    }
    const afterData = after.data() ?? {};
    const beforeData = before?.exists ? before.data() ?? {} : {};
    const status = normalizeVerificationNotificationStatus(afterData.status);
    const previousStatus = normalizeVerificationNotificationStatus(beforeData.status);
    if (before?.exists && status === previousStatus) {
        return;
    }
    const userId = cleanString(afterData.userId);
    const verificationType = cleanString(afterData.type) === "grey" ? "grey" : "blue";
    const targetName = cleanString(afterData.targetName) || "dein Profil";
    if (!userId) {
        firebase_functions_1.logger.warn("VERIFICATION_NOTIFICATION_SKIPPED_WITHOUT_USER", {
            requestId,
            status,
        });
        return;
    }
    const content = verificationNotificationContent({
        status,
        verificationType,
        targetName,
    });
    const notificationId = `verification_${requestId}_${status}`;
    const notificationReference = db
        .collection(usersCollection)
        .doc(userId)
        .collection("notifications")
        .doc(notificationId);
    await notificationReference.set({
        id: notificationId,
        userId,
        actorUserId: "",
        actorDisplayName: "",
        actorUsername: "",
        actorAvatarUrl: "",
        type: content.type,
        priority: content.priority,
        targetType: "verification",
        referenceId: requestId,
        secondaryReferenceId: null,
        friendshipId: null,
        previewText: content.previewText,
        contentThumbnailUrl: null,
        groupKey: `verification:${requestId}:${status}`,
        deduplicationKey: `verification:${requestId}:${status}`,
        groupCount: 1,
        actorUserIds: [],
        actorDisplayNames: [],
        groupedNotificationIds: [notificationId],
        unreadNotificationIds: [notificationId],
        title: content.title,
        body: content.body,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        readAt: null,
        isRead: false,
        isActionable: true,
        schemaVersion: 4,
        friendRequestStatus: null,
        verificationRequestId: requestId,
        verificationType,
        verificationStatus: status,
    }, { merge: true });
    await sendVerificationPush({
        userId,
        notificationId,
        requestId,
        verificationType,
        status,
        title: content.title,
        body: content.body,
    });
});
function normalizeVerificationNotificationStatus(value) {
    switch (cleanString(value)) {
        case "underReview":
        case "under_review":
        case "under-review":
            return "underReview";
        case "approved":
            return "approved";
        case "rejected":
            return "rejected";
        case "revoked":
            return "revoked";
        case "pending":
        default:
            return "pending";
    }
}
function verificationNotificationContent(input) {
    const badgeLabel = input.verificationType === "blue"
        ? "blauen Haken"
        : "grauen Haken";
    switch (input.status) {
        case "pending":
            return {
                type: "verificationSubmitted",
                priority: "medium",
                title: "Verifikationsantrag eingereicht",
                body: `Dein Antrag für den ${badgeLabel} wurde erfolgreich eingereicht.`,
                previewText: `${input.targetName} · Eingereicht`,
            };
        case "underReview":
            return {
                type: "verificationUnderReview",
                priority: "medium",
                title: "Verifikationsantrag wird geprüft",
                body: `Dein Antrag für den ${badgeLabel} wird jetzt von Luma geprüft.`,
                previewText: `${input.targetName} · In Prüfung`,
            };
        case "approved":
            return {
                type: "verificationApproved",
                priority: "high",
                title: "Verifikation genehmigt",
                body: `Der ${badgeLabel} wurde für ${input.targetName} genehmigt.`,
                previewText: `${input.targetName} · Genehmigt`,
            };
        case "rejected":
            return {
                type: "verificationRejected",
                priority: "high",
                title: "Verifikationsantrag abgelehnt",
                body: "Öffne Luma, um den Grund für die Ablehnung einzusehen.",
                previewText: `${input.targetName} · Abgelehnt`,
            };
        case "revoked":
            return {
                type: "verificationRevoked",
                priority: "high",
                title: "Verifikation entzogen",
                body: "Öffne Luma, um den Grund für den Entzug einzusehen.",
                previewText: `${input.targetName} · Entzogen`,
            };
    }
}
async function sendVerificationPush(input) {
    const [settingsSnapshot, tokensSnapshot] = await Promise.all([
        db
            .collection(usersCollection)
            .doc(input.userId)
            .collection(settingsCollection)
            .doc(appSettingsDocument)
            .get(),
        db
            .collection(usersCollection)
            .doc(input.userId)
            .collection("notification_tokens")
            .limit(500)
            .get(),
    ]);
    const settings = settingsSnapshot.data() ?? {};
    if (settings.inAppNotificationsEnabled === false ||
        settings.pushNotificationsEnabled === false) {
        return;
    }
    const tokenDocuments = tokensSnapshot.docs.filter((document) => {
        return cleanString(document.data().token).length > 20;
    });
    if (tokenDocuments.length === 0) {
        return;
    }
    const message = {
        tokens: tokenDocuments.map((document) => cleanString(document.data().token)),
        notification: {
            title: input.title,
            body: input.body,
        },
        data: {
            notificationId: input.notificationId,
            type: verificationNotificationTypeForStatus(input.status),
            targetType: "verification",
            referenceId: input.requestId,
            verificationRequestId: input.requestId,
            verificationType: input.verificationType,
            verificationStatus: input.status,
            navigationVersion: "2",
            source: "verification_notification",
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
                link: `/?pushNavigation=1&targetType=verification&` +
                    `verificationRequestId=${encodeURIComponent(input.requestId)}`,
            },
        },
    };
    const response = await (0, messaging_1.getMessaging)().sendEachForMulticast(message);
    const invalidDocuments = [];
    response.responses.forEach((result, index) => {
        if (result.success)
            return;
        const errorCode = result.error?.code ?? "";
        if (errorCode ===
            "messaging/registration-token-not-registered" ||
            errorCode === "messaging/invalid-registration-token") {
            invalidDocuments.push(tokenDocuments[index]);
            return;
        }
        firebase_functions_1.logger.error("VERIFICATION_PUSH_SEND_FAILED", {
            userId: input.userId,
            requestId: input.requestId,
            status: input.status,
            errorCode,
        });
    });
    if (invalidDocuments.length === 0) {
        return;
    }
    const batch = db.batch();
    invalidDocuments.forEach((document) => batch.delete(document.ref));
    await batch.commit();
}
function verificationNotificationTypeForStatus(status) {
    switch (status) {
        case "pending":
            return "verificationSubmitted";
        case "underReview":
            return "verificationUnderReview";
        case "approved":
            return "verificationApproved";
        case "rejected":
            return "verificationRejected";
        case "revoked":
            return "verificationRevoked";
    }
}
/**
 * Erzeugt eine kleinere JPEG-Vorschau erst nach erfolgreicher Erstellung
 * des Firestore-Beitrags.
 *
 * Dadurch existieren sowohl das Originalbild als auch das Post-Dokument,
 * bevor die Vorschau verarbeitet wird. Der bisherige Wettlauf zwischen
 * Storage-Trigger und App-Cleanup entfällt vollständig.
 */
exports.createFeedImagePreviewOnPostCreated = (0, firestore_2.onDocumentCreated)({
    document: "feed_posts/{postId}",
    timeoutSeconds: 120,
    memory: "1GiB",
}, async (event) => {
    const snapshot = event.data;
    const postId = cleanString(event.params.postId);
    if (!snapshot || !postId) {
        firebase_functions_1.logger.warn("Feed image preview skipped without post snapshot", {
            postId,
        });
        return;
    }
    const postData = snapshot.data() ?? {};
    const userId = cleanString(postData.userId) ||
        cleanString(postData.authorId);
    const imageUrl = cleanString(postData.imageUrl);
    const imageStoragePath = cleanString(postData.imageStoragePath);
    const existingPreviewUrl = cleanString(postData.feedImageUrl);
    if (!userId || !imageUrl || !imageStoragePath) {
        return;
    }
    if (existingPreviewUrl) {
        return;
    }
    const expectedOriginalPath = `${feedImagesRoot}/${userId}/${postId}/${feedImageOriginalFileName}`;
    if (imageStoragePath !== expectedOriginalPath) {
        firebase_functions_1.logger.warn("Feed image preview skipped for unexpected image path", {
            userId,
            postId,
            imageStoragePath,
            expectedOriginalPath,
        });
        return;
    }
    const previewPath = `${feedImagesRoot}/${userId}/${postId}/${feedImagePreviewFileName}`;
    const bucket = (0, storage_1.getStorage)().bucket();
    const sourceFile = bucket.file(imageStoragePath);
    const previewFile = bucket.file(previewPath);
    try {
        const [sourceExists] = await sourceFile.exists();
        if (!sourceExists) {
            firebase_functions_1.logger.warn("Feed image preview source object is missing", {
                userId,
                postId,
                imageStoragePath,
            });
            return;
        }
        const [sourceBuffer] = await sourceFile.download();
        const previewBuffer = await sharp(sourceBuffer)
            .rotate()
            .resize({
            width: feedImagePreviewMaxDimension,
            height: feedImagePreviewMaxDimension,
            fit: "inside",
            withoutEnlargement: true,
        })
            .jpeg({
            quality: feedImagePreviewJpegQuality,
            mozjpeg: true,
        })
            .toBuffer();
        const downloadToken = crypto.randomUUID();
        await previewFile.save(previewBuffer, {
            resumable: false,
            validation: "crc32c",
            metadata: {
                contentType: "image/jpeg",
                cacheControl: "public,max-age=31536000,immutable",
                metadata: {
                    userId,
                    postId,
                    scope: "feed_post_image_preview",
                    sourcePath: imageStoragePath,
                    firebaseStorageDownloadTokens: downloadToken,
                },
            },
        });
        const previewUrl = firebaseStorageDownloadUrl({
            bucketName: bucket.name,
            objectPath: previewPath,
            downloadToken,
        });
        await snapshot.ref.set({
            feedImageUrl: previewUrl,
            feedImageStoragePath: previewPath,
            feedImagePreviewUpdatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        firebase_functions_1.logger.info("Feed image preview ready", {
            userId,
            postId,
            sourcePath: imageStoragePath,
            previewPath,
            sourceBytes: sourceBuffer.length,
            previewBytes: previewBuffer.length,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Feed image preview generation failed", {
            userId,
            postId,
            imageStoragePath,
            previewPath,
            error,
        });
        throw error;
    }
});
function firebaseStorageDownloadUrl({ bucketName, objectPath, downloadToken, }) {
    return "https://firebasestorage.googleapis.com/v0/b/" +
        `${encodeURIComponent(bucketName)}/o/` +
        `${encodeURIComponent(objectPath)}` +
        `?alt=media&token=${encodeURIComponent(downloadToken)}`;
}
/**
 * Sendet eine vollständig gebrandete Luma-Passwort-Reset-Mail über Brevo.
 *
 * Die Antwort bleibt absichtlich neutral. Dadurch kann niemand über diese
 * Function prüfen, ob eine E-Mail-Adresse bei Luma registriert ist.
 */
exports.requestLumaPasswordReset = (0, https_1.onCall)({
    secrets: [brevoApiKeySecret],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (request) => {
    const email = normalizeEmailAddress(request.data?.email);
    if (!isValidEmailAddress(email)) {
        throw new https_1.HttpsError("invalid-argument", "Bitte gib eine gültige E-Mail-Adresse ein.");
    }
    const clientFingerprint = passwordResetClientFingerprint(request);
    const rateLimitAllowed = await consumePasswordResetRateLimit({
        email,
        clientFingerprint,
    });
    if (!rateLimitAllowed) {
        firebase_functions_1.logger.warn("Luma password reset rate limit reached", {
            emailHash: sha256Hex(email),
            clientFingerprint,
        });
        return passwordResetNeutralResponse();
    }
    let userRecord;
    try {
        userRecord = await (0, auth_1.getAuth)().getUserByEmail(email);
    }
    catch (error) {
        if (isFirebaseUserNotFoundError(error)) {
            firebase_functions_1.logger.info("Luma password reset accepted for unknown address", {
                emailHash: sha256Hex(email),
            });
            return passwordResetNeutralResponse();
        }
        firebase_functions_1.logger.error("Luma password reset user lookup failed", error);
        throw new https_1.HttpsError("unavailable", "Die Anfrage konnte momentan nicht verarbeitet werden.");
    }
    const supportsPasswordLogin = userRecord.providerData.some((provider) => provider.providerId === "password");
    if (userRecord.disabled || !supportsPasswordLogin) {
        firebase_functions_1.logger.info("Luma password reset skipped for ineligible account", {
            userId: userRecord.uid,
            disabled: userRecord.disabled,
            supportsPasswordLogin,
        });
        return passwordResetNeutralResponse();
    }
    let generatedResetLink;
    try {
        generatedResetLink = await (0, auth_1.getAuth)().generatePasswordResetLink(email, {
            url: lumaPasswordResetContinueUrl,
            handleCodeInApp: false,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Luma password reset link generation failed", error);
        throw new https_1.HttpsError("unavailable", "Der sichere Link konnte momentan nicht erstellt werden.");
    }
    const resetUrl = createLumaPasswordResetUrl(generatedResetLink);
    const displayName = cleanString(userRecord.displayName) || "Luma-Mitglied";
    try {
        await sendBrevoTransactionalEmail({
            apiKey: brevoApiKeySecret.value(),
            recipientEmail: email,
            recipientName: displayName,
            subject: "Setze dein Luma-Passwort zurück",
            htmlContent: createPasswordResetHtml({
                displayName,
                resetUrl,
            }),
            textContent: createPasswordResetText({
                displayName,
                resetUrl,
            }),
            tags: ["luma-auth", "password-reset"],
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Luma password reset Brevo delivery failed", error);
        throw new https_1.HttpsError("unavailable", "Die E-Mail konnte momentan nicht versendet werden.");
    }
    firebase_functions_1.logger.info("Luma password reset mail sent", {
        userId: userRecord.uid,
        emailHash: sha256Hex(email),
    });
    return passwordResetNeutralResponse();
});
/**
 * Sendet eine vollständig gebrandete Luma-E-Mail zur Bestätigung
 * der E-Mail-Adresse über Brevo.
 *
 * Die Function ist nur für angemeldete Nutzer verfügbar. Dadurch kann
 * niemand für fremde Adressen Verifizierungs-Mails auslösen.
 */
exports.requestLumaEmailVerification = (0, https_1.onCall)({
    secrets: [brevoApiKeySecret],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const userRecord = await (0, auth_1.getAuth)().getUser(userId);
    const email = normalizeEmailAddress(userRecord.email);
    if (!isValidEmailAddress(email)) {
        throw new https_1.HttpsError("failed-precondition", "Für dieses Konto ist keine gültige E-Mail-Adresse verfügbar.");
    }
    if (userRecord.disabled) {
        throw new https_1.HttpsError("permission-denied", "Dieses Luma-Konto ist deaktiviert.");
    }
    if (userRecord.emailVerified) {
        return {
            success: true,
            alreadyVerified: true,
            message: "Diese E-Mail-Adresse ist bereits bestätigt.",
        };
    }
    const clientFingerprint = passwordResetClientFingerprint(request);
    const rateLimitAllowed = await consumeEmailVerificationRateLimit({
        userId,
        email,
        clientFingerprint,
    });
    if (!rateLimitAllowed) {
        firebase_functions_1.logger.warn("Luma email verification rate limit reached", {
            userId,
            emailHash: sha256Hex(email),
            clientFingerprint,
        });
        throw new https_1.HttpsError("resource-exhausted", "Zu viele Verifizierungs-Anfragen. Bitte warte kurz.");
    }
    let generatedVerificationLink;
    try {
        generatedVerificationLink =
            await (0, auth_1.getAuth)().generateEmailVerificationLink(email, {
                url: lumaEmailVerificationContinueUrl,
                handleCodeInApp: false,
            });
    }
    catch (error) {
        firebase_functions_1.logger.error("Luma email verification link generation failed", error);
        throw new https_1.HttpsError("unavailable", "Der sichere Bestätigungslink konnte momentan nicht erstellt werden.");
    }
    const verificationUrl = createLumaEmailVerificationUrl(generatedVerificationLink);
    const displayName = cleanString(userRecord.displayName) || "Luma-Mitglied";
    try {
        await sendBrevoTransactionalEmail({
            apiKey: brevoApiKeySecret.value(),
            recipientEmail: email,
            recipientName: displayName,
            subject: "Bestätige deine E-Mail-Adresse für Luma",
            htmlContent: createEmailVerificationHtml({
                displayName,
                verificationUrl,
            }),
            textContent: createEmailVerificationText({
                displayName,
                verificationUrl,
            }),
            tags: ["luma-auth", "email-verification"],
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Luma email verification Brevo delivery failed", error);
        throw new https_1.HttpsError("unavailable", "Die Bestätigungs-E-Mail konnte momentan nicht versendet werden.");
    }
    firebase_functions_1.logger.info("Luma email verification mail sent", {
        userId,
        emailHash: sha256Hex(email),
    });
    return {
        success: true,
        alreadyVerified: false,
        message: "Bestätigungs-E-Mail wurde gesendet.",
    };
});
exports.revokeOtherSessions = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const currentDeviceId = cleanString(request.data?.currentDeviceId);
    const activeDevicesSnapshot = await db
        .collection(usersCollection)
        .doc(userId)
        .collection(devicesCollection)
        .where("active", "==", true)
        .get();
    const batch = db.batch();
    let deactivatedDeviceCount = 0;
    let currentDeviceWasFound = false;
    for (const deviceDocument of activeDevicesSnapshot.docs) {
        const deviceData = deviceDocument.data();
        const storedDeviceId = cleanString(deviceData.id) || deviceDocument.id;
        const isCurrentDevice = currentDeviceId.length > 0 &&
            (deviceDocument.id === currentDeviceId ||
                storedDeviceId === currentDeviceId);
        if (isCurrentDevice) {
            currentDeviceWasFound = true;
            batch.set(deviceDocument.ref, {
                active: true,
                lastSeenAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            continue;
        }
        batch.set(deviceDocument.ref, {
            active: false,
            disabledAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        deactivatedDeviceCount += 1;
    }
    await batch.commit();
    await (0, auth_1.getAuth)().revokeRefreshTokens(userId);
    const userRecord = await (0, auth_1.getAuth)().getUser(userId);
    await db
        .collection(usersCollection)
        .doc(userId)
        .collection(securityCollection)
        .doc(sessionPolicyDocument)
        .set({
        userId,
        currentDeviceId: currentDeviceId || null,
        currentDeviceWasFound,
        deactivatedDeviceCount,
        requiresReauthentication: true,
        reason: "remote_logout",
        tokensRevokedAt: firestore_1.FieldValue.serverTimestamp(),
        tokensValidAfterTime: userRecord.tokensValidAfterTime ?? null,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await createSecurityEvent({
        userId,
        type: "remote_logout",
        severity: "high",
        title: "Andere Geräte abgemeldet",
        description: remoteLogoutDescription(deactivatedDeviceCount),
        deviceId: currentDeviceId || null,
        deviceName: null,
        platformLabel: null,
        read: false,
    });
    await createSecurityAlert({
        userId,
        type: "remote_logout",
        title: "Andere Geräte abgemeldet",
        body: remoteLogoutAlertBody(deactivatedDeviceCount),
        referenceId: currentDeviceId || null,
    });
    await updateSecurityTimeline({
        userId,
        increaseUnreadCount: true,
    });
    return {
        success: true,
        currentDeviceId: currentDeviceId || null,
        currentDeviceWasFound,
        deactivatedDeviceCount,
        tokensValidAfterTime: userRecord.tokensValidAfterTime ?? null,
    };
});
exports.recordNewDeviceDetected = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const deviceId = cleanString(request.data?.deviceId);
    const deviceName = cleanString(request.data?.deviceName) || "Unbekanntes Gerät";
    const platformLabel = cleanString(request.data?.platformLabel) || "Unbekannte Plattform";
    if (!deviceId) {
        throw new https_1.HttpsError("invalid-argument", "deviceId fehlt.");
    }
    await recordNewDeviceDetectedInternal({
        userId,
        deviceId,
        deviceName,
        platformLabel,
    });
    return {
        success: true,
        deviceId,
    };
});
exports.recordPhoneNumberChanged = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const phoneNumber = cleanString(request.data?.phoneNumber);
    const verified = request.data?.verified === true;
    await createSecurityEvent({
        userId,
        type: verified ? "phone_verified" : "phone_changed",
        severity: verified ? "low" : "medium",
        title: verified ? "Telefonnummer bestätigt" : "Telefonnummer geändert",
        description: verified
            ? "Die Telefonnummer wurde erfolgreich bestätigt."
            : "Die Telefonnummer für Sicherheit und Wiederherstellung wurde geändert.",
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: verified,
    });
    await createSecurityAlert({
        userId,
        type: "phone_changed",
        title: verified ? "Telefonnummer bestätigt" : "Telefonnummer geändert",
        body: verified
            ? "Die Telefonnummer deines Luma-Kontos wurde bestätigt."
            : "Die Telefonnummer deines Luma-Kontos wurde geändert.",
        referenceId: null,
    });
    await updateSettingsDocument(userId, {
        phoneNumber: phoneNumber || null,
        isPhoneNumberVerified: verified,
        phoneNumberUpdatedAt: firestore_1.FieldValue.serverTimestamp(),
        phoneNumberVerifiedAt: verified ? firestore_1.FieldValue.serverTimestamp() : null,
    });
    await updateSecurityTimeline({
        userId,
        increaseUnreadCount: !verified,
    });
    return {
        success: true,
        verified,
    };
});
exports.recordTwoFactorChanged = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const enabled = request.data?.enabled === true;
    const method = normalizeTwoFactorMethod(request.data?.method);
    await createSecurityEvent({
        userId,
        type: enabled ? "two_factor_enabled" : "two_factor_disabled",
        severity: enabled ? "low" : "high",
        title: enabled
            ? "Zwei-Faktor-Schutz aktiviert"
            : "Zwei-Faktor-Schutz deaktiviert",
        description: enabled
            ? twoFactorEnabledDescription(method)
            : "Die zweite Sicherheitsebene wurde deaktiviert.",
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: enabled,
    });
    await createSecurityAlert({
        userId,
        type: "two_factor_changed",
        title: enabled
            ? "Zwei-Faktor-Schutz aktiviert"
            : "Zwei-Faktor-Schutz deaktiviert",
        body: enabled
            ? twoFactorEnabledDescription(method)
            : "Der Zwei-Faktor-Schutz deines Luma-Kontos wurde deaktiviert.",
        referenceId: null,
    });
    await updateSettingsDocument(userId, {
        twoFactorEnabled: enabled,
        twoFactorMethod: enabled ? method : "none",
    });
    await updateSecurityTimeline({
        userId,
        increaseUnreadCount: !enabled,
    });
    return {
        success: true,
        enabled,
        method: enabled ? method : "none",
    };
});
exports.recordBackupCodesChanged = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const generated = request.data?.generated === true;
    const availableCodeCount = readNumber(request.data?.availableCodeCount);
    await createSecurityEvent({
        userId,
        type: generated ? "backup_codes_generated" : "backup_codes_reset",
        severity: generated ? "low" : "medium",
        title: generated ? "Backup-Codes erstellt" : "Backup-Codes zurückgesetzt",
        description: generated
            ? backupCodesGeneratedDescription(availableCodeCount)
            : "Die Backup-Codes wurden zurückgesetzt oder widerrufen.",
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: generated,
    });
    await createSecurityAlert({
        userId,
        type: "backup_codes_changed",
        title: generated ? "Backup-Codes erstellt" : "Backup-Codes zurückgesetzt",
        body: generated
            ? backupCodesGeneratedDescription(availableCodeCount)
            : "Die Backup-Codes deines Luma-Kontos wurden zurückgesetzt.",
        referenceId: null,
    });
    await updateSettingsDocument(userId, {
        backupCodesGenerated: generated,
        backupCodesGeneratedAt: generated ? firestore_1.FieldValue.serverTimestamp() : null,
    });
    await updateSecurityTimeline({
        userId,
        increaseUnreadCount: !generated,
    });
    return {
        success: true,
        generated,
        availableCodeCount,
    };
});
exports.generateBackupCodes = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const requestedCount = readNumber(request.data?.count);
    const count = Math.min(Math.max(requestedCount || 10, 6), 20);
    const existingCodesSnapshot = await backupCodesCollection(userId)
        .limit(400)
        .get();
    const batch = db.batch();
    for (const codeDocument of existingCodesSnapshot.docs) {
        batch.set(codeDocument.ref, {
            revokedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    const codes = [];
    for (let index = 0; index < count; index += 1) {
        const code = generateHumanBackupCode();
        codes.push(code);
        const codeReference = backupCodesCollection(userId).doc();
        batch.set(codeReference, {
            id: codeReference.id,
            userId,
            codeHash: hashBackupCode(userId, code),
            used: false,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            usedAt: null,
            revokedAt: null,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    }
    batch.set(backupCodesSummaryDocument(userId), {
        userId,
        generatedAt: firestore_1.FieldValue.serverTimestamp(),
        availableCodeCount: codes.length,
        totalCodeCount: codes.length,
        usedCodeCount: 0,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await updateSettingsDocument(userId, {
        backupCodesGenerated: true,
        backupCodesGeneratedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await createSecurityEvent({
        userId,
        type: "backup_codes_generated",
        severity: "low",
        title: "Backup-Codes erstellt",
        description: backupCodesGeneratedDescription(codes.length),
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: true,
    });
    await createSecurityAlert({
        userId,
        type: "backup_codes_changed",
        title: "Backup-Codes erstellt",
        body: backupCodesGeneratedDescription(codes.length),
        referenceId: null,
    });
    return {
        success: true,
        codes,
        generatedCount: codes.length,
    };
});
exports.verifyBackupCode = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const code = normalizeBackupCode(cleanString(request.data?.code));
    if (!code) {
        throw new https_1.HttpsError("invalid-argument", "Backup-Code fehlt.");
    }
    const snapshot = await backupCodesCollection(userId)
        .where("codeHash", "==", hashBackupCode(userId, code))
        .where("used", "==", false)
        .limit(1)
        .get();
    if (snapshot.empty) {
        return {
            success: true,
            valid: false,
        };
    }
    const codeDocument = snapshot.docs[0];
    const revokedAt = codeDocument.data().revokedAt;
    if (revokedAt !== null && revokedAt !== undefined) {
        return {
            success: true,
            valid: false,
        };
    }
    await codeDocument.ref.set({
        used: true,
        usedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const summary = await calculateBackupCodeSummary(userId);
    await backupCodesSummaryDocument(userId).set({
        availableCodeCount: summary.availableCodeCount,
        totalCodeCount: summary.totalCodeCount,
        usedCodeCount: summary.usedCodeCount,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await createSecurityEvent({
        userId,
        type: "backup_code_used",
        severity: "medium",
        title: "Backup-Code verwendet",
        description: "Ein Backup-Code wurde zur Sicherheitswiederherstellung verwendet.",
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: false,
    });
    await updateSecurityTimeline({
        userId,
        increaseUnreadCount: true,
    });
    return {
        success: true,
        valid: true,
    };
});
exports.revokeBackupCodes = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const existingCodesSnapshot = await backupCodesCollection(userId)
        .limit(400)
        .get();
    const batch = db.batch();
    for (const codeDocument of existingCodesSnapshot.docs) {
        batch.set(codeDocument.ref, {
            revokedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    batch.set(backupCodesSummaryDocument(userId), {
        availableCodeCount: 0,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();
    await updateSettingsDocument(userId, {
        backupCodesGenerated: false,
        backupCodesGeneratedAt: null,
    });
    await createSecurityEvent({
        userId,
        type: "backup_codes_reset",
        severity: "medium",
        title: "Backup-Codes zurückgesetzt",
        description: "Alle Backup-Codes wurden zurückgesetzt oder widerrufen.",
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: false,
    });
    await createSecurityAlert({
        userId,
        type: "backup_codes_changed",
        title: "Backup-Codes zurückgesetzt",
        body: "Die Backup-Codes deines Luma-Kontos wurden zurückgesetzt.",
        referenceId: null,
    });
    await updateSecurityTimeline({
        userId,
        increaseUnreadCount: true,
    });
    return {
        success: true,
    };
});
exports.prepareAuthenticatorTotp = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const userRecord = await (0, auth_1.getAuth)().getUser(userId);
    const accountName = userRecord.email || userRecord.phoneNumber || userId;
    const secret = generateBase32Secret();
    await totpDocumentReference(userId).set({
        userId,
        pendingSecret: secret,
        activeSecret: null,
        enabled: false,
        issuer: "Luma",
        accountName,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        success: true,
        secret,
        provisioningUri: createTotpProvisioningUri({
            issuer: "Luma",
            accountName,
            secret,
        }),
    };
});
exports.verifyAuthenticatorTotp = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const code = cleanString(request.data?.code).replace(/\s+/g, "");
    if (!/^\d{6}$/.test(code)) {
        throw new https_1.HttpsError("invalid-argument", "Authenticator-Code ungültig.");
    }
    const document = await totpDocumentReference(userId).get();
    const data = document.data();
    if (!data) {
        throw new https_1.HttpsError("failed-precondition", "Keine Authenticator-Einrichtung gefunden.");
    }
    const pendingSecret = cleanString(data.pendingSecret);
    const activeSecret = cleanString(data.activeSecret);
    const secret = pendingSecret || activeSecret;
    if (!secret) {
        throw new https_1.HttpsError("failed-precondition", "Kein Authenticator-Secret gefunden.");
    }
    const valid = verifyTotp({
        secret,
        code,
    });
    if (!valid) {
        return {
            success: true,
            valid: false,
        };
    }
    await totpDocumentReference(userId).set({
        activeSecret: secret,
        pendingSecret: null,
        enabled: true,
        verifiedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await updateSettingsDocument(userId, {
        twoFactorEnabled: true,
        twoFactorMethod: "authenticator",
    });
    await createSecurityEvent({
        userId,
        type: "two_factor_enabled",
        severity: "low",
        title: "Zwei-Faktor-Schutz aktiviert",
        description: "Der Zwei-Faktor-Schutz wurde per Authenticator-App aktiviert.",
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: true,
    });
    await createSecurityAlert({
        userId,
        type: "two_factor_changed",
        title: "Zwei-Faktor-Schutz aktiviert",
        body: "Der Zwei-Faktor-Schutz wurde per Authenticator-App aktiviert.",
        referenceId: null,
    });
    return {
        success: true,
        valid: true,
    };
});
/**
 * Ermittelt serverseitig, ob für die aktuelle Firebase-Sitzung
 * wirklich eine zweite Sicherheitsstufe erforderlich ist.
 *
 * Ein twoFactorEnabled=true in users/{uid}/settings/app reicht für
 * Authenticator-2FA nicht aus. Zusätzlich muss das serverseitige
 * TOTP-Dokument aktiviert sein und ein activeSecret besitzen.
 *
 * Veraltete oder inkonsistente Settings aus älteren App-Versionen
 * dürfen dadurch keinen Nutzer fälschlich aussperren.
 */
exports.getTwoFactorLoginRequirement = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const settingsSnapshot = await db
        .collection(usersCollection)
        .doc(userId)
        .collection(settingsCollection)
        .doc(appSettingsDocument)
        .get();
    const settingsData = settingsSnapshot.data() ?? {};
    const settingsEnabled = settingsData.twoFactorEnabled === true;
    const settingsMethod = normalizeTwoFactorMethod(settingsData.twoFactorMethod);
    if (!settingsEnabled || settingsMethod === "none") {
        return {
            success: true,
            enabled: false,
            method: "none",
        };
    }
    if (settingsMethod === "authenticator") {
        const totpSnapshot = await totpDocumentReference(userId).get();
        const totpData = totpSnapshot.data() ?? {};
        const totpEnabled = totpData.enabled === true;
        const activeSecret = cleanString(totpData.activeSecret);
        if (!totpEnabled || !activeSecret) {
            firebase_functions_1.logger.warn("TWO_FACTOR_INCONSISTENT_AUTHENTICATOR_STATE", {
                userId,
                settingsEnabled,
                settingsMethod,
                totpExists: totpSnapshot.exists,
                totpEnabled,
                hasActiveSecret: activeSecret.length > 0,
            });
            await updateSettingsDocument(userId, {
                twoFactorEnabled: false,
                twoFactorMethod: "none",
            });
            return {
                success: true,
                enabled: false,
                method: "none",
                repairedInconsistentState: true,
            };
        }
        return {
            success: true,
            enabled: true,
            method: "authenticator",
        };
    }
    return {
        success: true,
        enabled: true,
        method: "sms",
    };
});
/**
 * Prüft einen Authenticator-Code ausschließlich für den Login.
 *
 * Anders als verifyAuthenticatorTotp verändert diese Function keine
 * TOTP-Einrichtung und aktiviert 2FA nicht erneut. Es wird ausschließlich
 * das bereits aktive Secret verwendet.
 */
exports.verifyAuthenticatorLoginTotp = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const code = cleanString(request.data?.code).replace(/\s+/g, "");
    if (!/^\d{6}$/.test(code)) {
        throw new https_1.HttpsError("invalid-argument", "Authenticator-Code ungültig.");
    }
    const settingsSnapshot = await db
        .collection(usersCollection)
        .doc(userId)
        .collection(settingsCollection)
        .doc(appSettingsDocument)
        .get();
    const settingsData = settingsSnapshot.data() ?? {};
    const twoFactorEnabled = settingsData.twoFactorEnabled === true;
    const twoFactorMethod = cleanString(settingsData.twoFactorMethod);
    if (!twoFactorEnabled || twoFactorMethod !== "authenticator") {
        throw new https_1.HttpsError("failed-precondition", "Authenticator-2FA ist für dieses Konto nicht aktiv.");
    }
    const totpSnapshot = await totpDocumentReference(userId).get();
    const totpData = totpSnapshot.data();
    if (!totpData || totpData.enabled !== true) {
        throw new https_1.HttpsError("failed-precondition", "Keine aktive Authenticator-Einrichtung gefunden.");
    }
    const activeSecret = cleanString(totpData.activeSecret);
    if (!activeSecret) {
        throw new https_1.HttpsError("failed-precondition", "Kein aktives Authenticator-Secret gefunden.");
    }
    const valid = verifyTotp({
        secret: activeSecret,
        code,
    });
    return {
        success: true,
        valid,
    };
});
exports.disableAuthenticatorTotp = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    await totpDocumentReference(userId).set({
        activeSecret: null,
        pendingSecret: null,
        enabled: false,
        disabledAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await updateSettingsDocument(userId, {
        twoFactorEnabled: false,
        twoFactorMethod: "none",
    });
    await createSecurityEvent({
        userId,
        type: "two_factor_disabled",
        severity: "high",
        title: "Zwei-Faktor-Schutz deaktiviert",
        description: "Der Authenticator-Schutz wurde deaktiviert.",
        deviceId: null,
        deviceName: null,
        platformLabel: null,
        read: false,
    });
    await createSecurityAlert({
        userId,
        type: "two_factor_changed",
        title: "Zwei-Faktor-Schutz deaktiviert",
        body: "Der Zwei-Faktor-Schutz deines Luma-Kontos wurde deaktiviert.",
        referenceId: null,
    });
    await updateSecurityTimeline({
        userId,
        increaseUnreadCount: true,
    });
    return {
        success: true,
    };
});
exports.createAgoraRtcToken = (0, https_1.onCall)({
    secrets: [agoraAppIdSecret, agoraAppCertificateSecret],
}, async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const callId = cleanString(request.data?.callId);
    const channelId = cleanString(request.data?.channelId);
    const uid = readPositiveNumber(request.data?.uid);
    if (!callId) {
        throw new https_1.HttpsError("invalid-argument", "callId fehlt.");
    }
    if (!channelId) {
        throw new https_1.HttpsError("invalid-argument", "channelId fehlt.");
    }
    if (uid <= 0) {
        throw new https_1.HttpsError("invalid-argument", "Agora uid ist ungültig.");
    }
    const expectedChannelId = `luma_call_${callId}`;
    if (channelId !== expectedChannelId) {
        throw new https_1.HttpsError("permission-denied", "Agora Channel passt nicht zum Anruf.");
    }
    const callDocument = await db
        .collection(callsCollection)
        .doc(callId)
        .get();
    if (!callDocument.exists) {
        throw new https_1.HttpsError("not-found", "Anruf wurde nicht gefunden.");
    }
    const callData = callDocument.data() ?? {};
    const participantIds = readStringArray(callData.participantIds);
    const callerUserId = cleanString(callData.callerUserId);
    const receiverUserId = cleanString(callData.receiverUserId);
    const status = cleanString(callData.status);
    const isParticipant = participantIds.includes(userId) ||
        callerUserId === userId ||
        receiverUserId === userId;
    if (!isParticipant) {
        throw new https_1.HttpsError("permission-denied", "Du bist kein Teilnehmer dieses Anrufs.");
    }
    const allowedStatuses = new Set(["ringing", "accepted"]);
    if (!allowedStatuses.has(status)) {
        throw new https_1.HttpsError("failed-precondition", "Für diesen Anruf kann kein RTC Token mehr erstellt werden.");
    }
    const appId = agoraAppIdSecret.value().trim();
    const appCertificate = agoraAppCertificateSecret.value().trim();
    if (!appId || !appCertificate) {
        throw new https_1.HttpsError("failed-precondition", "Agora Secrets sind serverseitig nicht vollständig konfiguriert.");
    }
    const nowInSeconds = Math.floor(Date.now() / 1000);
    const expiresAt = nowInSeconds + agoraRtcTokenExpirySeconds;
    const token = agora_access_token_1.RtcTokenBuilder.buildTokenWithUid(appId, appCertificate, channelId, uid, agora_access_token_1.RtcRole.PUBLISHER, expiresAt);
    if (!token) {
        throw new https_1.HttpsError("internal", "Agora Token konnte nicht erstellt werden.");
    }
    return {
        success: true,
        token,
        channelId,
        uid,
        expiresAt,
        expiresInSeconds: agoraRtcTokenExpirySeconds,
    };
});
async function recordNewDeviceDetectedInternal(input) {
    await createSecurityEvent({
        userId: input.userId,
        type: "device_registered",
        severity: "medium",
        title: "Neues Gerät erkannt",
        description: `Ein neues Gerät wurde für dein Luma-Konto erkannt: ${input.deviceName}.`,
        deviceId: input.deviceId,
        deviceName: input.deviceName,
        platformLabel: input.platformLabel,
        read: false,
    });
    await createSecurityAlert({
        userId: input.userId,
        type: "new_device",
        title: "Neues Gerät erkannt",
        body: `Ein neues Gerät wurde für dein Luma-Konto erkannt: ${input.deviceName}.`,
        referenceId: input.deviceId,
    });
    await updateSecurityTimeline({
        userId: input.userId,
        increaseUnreadCount: true,
    });
}
async function createSecurityEvent(input) {
    const eventReference = db
        .collection(usersCollection)
        .doc(input.userId)
        .collection(securityEventsCollection)
        .doc();
    await eventReference.set({
        id: eventReference.id,
        userId: input.userId,
        type: input.type,
        severity: input.severity,
        title: input.title,
        description: input.description,
        deviceId: input.deviceId,
        deviceName: input.deviceName,
        platformLabel: input.platformLabel,
        read: input.read,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        readAt: input.read ? firestore_1.FieldValue.serverTimestamp() : null,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
}
async function createSecurityAlert(input) {
    const alertReference = db
        .collection(usersCollection)
        .doc(input.userId)
        .collection(securityAlertsCollection)
        .doc();
    await alertReference.set({
        id: alertReference.id,
        userId: input.userId,
        type: input.type,
        status: "unread",
        title: input.title,
        body: input.body,
        referenceId: input.referenceId,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        readAt: null,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
}
async function updateSettingsDocument(userId, values) {
    await db
        .collection(usersCollection)
        .doc(userId)
        .collection(settingsCollection)
        .doc(appSettingsDocument)
        .set({
        ...values,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function updateSecurityTimeline(input) {
    const updateData = {
        "securityTimelineSummary.lastSecurityEventAt": firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    if (input.increaseUnreadCount) {
        updateData["securityTimelineSummary.unreadSecurityEventCount"] =
            firestore_1.FieldValue.increment(1);
    }
    await db
        .collection(usersCollection)
        .doc(input.userId)
        .collection(settingsCollection)
        .doc(appSettingsDocument)
        .set(updateData, { merge: true });
}
function backupCodesCollection(userId) {
    return db
        .collection(usersCollection)
        .doc(userId)
        .collection(securityCollection)
        .doc(backupCodesDocument)
        .collection(codesCollection);
}
function backupCodesSummaryDocument(userId) {
    return db
        .collection(usersCollection)
        .doc(userId)
        .collection(securityCollection)
        .doc(backupCodesDocument);
}
function totpDocumentReference(userId) {
    return db
        .collection(usersCollection)
        .doc(userId)
        .collection(securityCollection)
        .doc(totpDocument);
}
async function calculateBackupCodeSummary(userId) {
    const snapshot = await backupCodesCollection(userId).get();
    let totalCodeCount = 0;
    let availableCodeCount = 0;
    let usedCodeCount = 0;
    for (const document of snapshot.docs) {
        const data = document.data();
        if (data.revokedAt !== null && data.revokedAt !== undefined) {
            continue;
        }
        totalCodeCount += 1;
        if (data.used === true) {
            usedCodeCount += 1;
        }
        else {
            availableCodeCount += 1;
        }
    }
    return {
        totalCodeCount,
        availableCodeCount,
        usedCodeCount,
    };
}
function requireAuthenticatedUserId(value) {
    const userId = cleanString(value);
    if (!userId) {
        throw new https_1.HttpsError("unauthenticated", "Bitte melde dich erneut an.");
    }
    return userId;
}
function cleanString(value) {
    if (typeof value !== "string") {
        return "";
    }
    return value.trim();
}
function readNumber(value) {
    if (typeof value === "number" && Number.isFinite(value)) {
        return Math.max(0, Math.floor(value));
    }
    return 0;
}
function normalizeTwoFactorMethod(value) {
    const method = cleanString(value);
    if (method === "sms" || method === "authenticator") {
        return method;
    }
    return "none";
}
function readPositiveNumber(value) {
    if (typeof value === "number" && Number.isFinite(value)) {
        return Math.max(0, Math.floor(value));
    }
    if (typeof value === "string") {
        const parsed = Number.parseInt(value.trim(), 10);
        if (Number.isFinite(parsed)) {
            return Math.max(0, Math.floor(parsed));
        }
    }
    return 0;
}
function readStringArray(value) {
    if (!Array.isArray(value)) {
        return [];
    }
    return value
        .map((item) => cleanString(item))
        .filter((item) => item.length > 0);
}
function remoteLogoutDescription(deactivatedDeviceCount) {
    if (deactivatedDeviceCount === 0) {
        return "Es wurden keine weiteren aktiven Geräte gefunden. Firebase Refresh Tokens wurden trotzdem serverseitig widerrufen.";
    }
    if (deactivatedDeviceCount === 1) {
        return "1 anderes Gerät wurde deaktiviert. Firebase Refresh Tokens wurden serverseitig widerrufen.";
    }
    return `${deactivatedDeviceCount} andere Geräte wurden deaktiviert. Firebase Refresh Tokens wurden serverseitig widerrufen.`;
}
function remoteLogoutAlertBody(deactivatedDeviceCount) {
    if (deactivatedDeviceCount === 0) {
        return "Es wurden keine weiteren aktiven Geräte gefunden. Deine Sitzungssicherheit wurde trotzdem serverseitig aktualisiert.";
    }
    if (deactivatedDeviceCount === 1) {
        return "1 anderes Gerät wurde von deinem Luma-Konto abgemeldet.";
    }
    return `${deactivatedDeviceCount} andere Geräte wurden von deinem Luma-Konto abgemeldet.`;
}
function twoFactorEnabledDescription(method) {
    if (method === "sms") {
        return "Der Zwei-Faktor-Schutz wurde per SMS aktiviert.";
    }
    if (method === "authenticator") {
        return "Der Zwei-Faktor-Schutz wurde per Authenticator-App aktiviert.";
    }
    return "Der Zwei-Faktor-Schutz wurde aktiviert.";
}
function backupCodesGeneratedDescription(availableCodeCount) {
    if (availableCodeCount <= 0) {
        return "Neue Backup-Codes wurden für dein Luma-Konto erstellt.";
    }
    if (availableCodeCount === 1) {
        return "1 neuer Backup-Code wurde für dein Luma-Konto erstellt.";
    }
    return `${availableCodeCount} neue Backup-Codes wurden für dein Luma-Konto erstellt.`;
}
function generateHumanBackupCode() {
    const first = randomFromAlphabet(4, backupCodeAlphabet);
    const second = randomFromAlphabet(4, backupCodeAlphabet);
    const third = randomFromAlphabet(4, backupCodeAlphabet);
    return `${first}-${second}-${third}`;
}
const backupCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
function randomFromAlphabet(length, alphabet) {
    const bytes = crypto.randomBytes(length);
    let output = "";
    for (const byte of bytes) {
        output += alphabet[byte % alphabet.length];
    }
    return output;
}
function normalizeBackupCode(value) {
    return value.toUpperCase().replace(/\s+/g, "");
}
function hashBackupCode(userId, code) {
    return crypto
        .createHash("sha256")
        .update(`${userId}::${normalizeBackupCode(code)}`)
        .digest("hex");
}
function generateBase32Secret() {
    return randomFromAlphabet(32, base32Alphabet);
}
function createTotpProvisioningUri(input) {
    const encodedLabel = encodeURIComponent(`${input.issuer}:${input.accountName}`);
    const encodedIssuer = encodeURIComponent(input.issuer);
    return `otpauth://totp/${encodedLabel}?secret=${input.secret}&issuer=${encodedIssuer}&algorithm=SHA1&digits=6&period=30`;
}
function verifyTotp(input) {
    const currentStep = Math.floor(Date.now() / 1000 / 30);
    for (let offset = -1; offset <= 1; offset += 1) {
        const expected = generateTotp({
            secret: input.secret,
            timeStep: currentStep + offset,
        });
        if (expected === input.code) {
            return true;
        }
    }
    return false;
}
function generateTotp(input) {
    const key = base32Decode(input.secret);
    const counterBuffer = Buffer.alloc(8);
    counterBuffer.writeBigUInt64BE(BigInt(input.timeStep), 0);
    const hmac = crypto
        .createHmac("sha1", key)
        .update(counterBuffer)
        .digest();
    const offset = hmac[hmac.length - 1] & 0x0f;
    const binary = ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);
    return (binary % 1000000).toString().padStart(6, "0");
}
function base32Decode(value) {
    const cleaned = value.toUpperCase().replace(/=+$/g, "");
    let bits = "";
    const bytes = [];
    for (const character of cleaned) {
        const index = base32Alphabet.indexOf(character);
        if (index < 0) {
            continue;
        }
        bits += index.toString(2).padStart(5, "0");
    }
    for (let index = 0; index + 8 <= bits.length; index += 8) {
        bytes.push(parseInt(bits.substring(index, index + 8), 2));
    }
    return Buffer.from(bytes);
}
function normalizeEmailAddress(value) {
    return cleanString(value).toLowerCase();
}
function isValidEmailAddress(value) {
    if (value.length < 5 || value.length > 254) {
        return false;
    }
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}
function passwordResetNeutralResponse() {
    return {
        success: true,
        message: "Falls ein Luma-Konto zu dieser E-Mail-Adresse existiert, " +
            "haben wir dir einen sicheren Link gesendet.",
    };
}
function passwordResetClientFingerprint(request) {
    const forwardedFor = request.rawRequest.headers["x-forwarded-for"];
    const forwardedValue = Array.isArray(forwardedFor)
        ? forwardedFor[0]
        : forwardedFor;
    const ipAddress = cleanString(forwardedValue).split(",")[0].trim() ||
        cleanString(request.rawRequest.ip) ||
        "unknown";
    const userAgentHeader = request.rawRequest.headers["user-agent"];
    const userAgent = Array.isArray(userAgentHeader)
        ? userAgentHeader[0]
        : userAgentHeader;
    return sha256Hex(`${ipAddress}::${cleanString(userAgent)}`).slice(0, 32);
}
async function consumePasswordResetRateLimit(input) {
    const emailHash = sha256Hex(input.email);
    const documentId = sha256Hex(`${emailHash}::${input.clientFingerprint}`);
    const reference = db
        .collection(authEmailRateLimitsCollection)
        .doc(documentId);
    const nowMs = Date.now();
    return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        const data = snapshot.data() ?? {};
        const storedWindowStartedAtMs = readPositiveNumber(data.windowStartedAtMs);
        const storedRequestCount = readPositiveNumber(data.requestCount);
        const windowExpired = storedWindowStartedAtMs <= 0 ||
            nowMs - storedWindowStartedAtMs >= passwordResetRateLimitWindowMs;
        if (!windowExpired &&
            storedRequestCount >= passwordResetMaxRequestsPerWindow) {
            transaction.set(reference, {
                emailHash,
                clientFingerprint: input.clientFingerprint,
                lastRejectedAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            return false;
        }
        transaction.set(reference, {
            emailHash,
            clientFingerprint: input.clientFingerprint,
            windowStartedAtMs: windowExpired
                ? nowMs
                : storedWindowStartedAtMs,
            requestCount: windowExpired
                ? 1
                : storedRequestCount + 1,
            lastAcceptedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
    });
}
async function consumeEmailVerificationRateLimit(input) {
    const emailHash = sha256Hex(input.email);
    const documentId = sha256Hex(`email-verification::${input.userId}::${emailHash}::${input.clientFingerprint}`);
    const reference = db
        .collection(authEmailRateLimitsCollection)
        .doc(documentId);
    const nowMs = Date.now();
    return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        const data = snapshot.data() ?? {};
        const storedWindowStartedAtMs = readPositiveNumber(data.windowStartedAtMs);
        const storedRequestCount = readPositiveNumber(data.requestCount);
        const windowExpired = storedWindowStartedAtMs <= 0 ||
            nowMs - storedWindowStartedAtMs >=
                emailVerificationRateLimitWindowMs;
        if (!windowExpired &&
            storedRequestCount >= emailVerificationMaxRequestsPerWindow) {
            transaction.set(reference, {
                type: "email-verification",
                userId: input.userId,
                emailHash,
                clientFingerprint: input.clientFingerprint,
                lastRejectedAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            return false;
        }
        transaction.set(reference, {
            type: "email-verification",
            userId: input.userId,
            emailHash,
            clientFingerprint: input.clientFingerprint,
            windowStartedAtMs: windowExpired
                ? nowMs
                : storedWindowStartedAtMs,
            requestCount: windowExpired
                ? 1
                : storedRequestCount + 1,
            lastAcceptedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
    });
}
function isFirebaseUserNotFoundError(error) {
    if (typeof error !== "object" || error === null) {
        return false;
    }
    const code = cleanString(error.code);
    return code === "auth/user-not-found" || code === "user-not-found";
}
function createLumaPasswordResetUrl(firebaseActionLink) {
    let generatedUrl;
    try {
        generatedUrl = new URL(firebaseActionLink);
    }
    catch (error) {
        firebase_functions_1.logger.error("Firebase password reset link is not a valid URL", {
            error: String(error),
        });
        throw new Error("Der von Firebase erzeugte Passwort-Link ist ungültig.");
    }
    const mode = cleanString(generatedUrl.searchParams.get("mode"));
    const oobCode = cleanString(generatedUrl.searchParams.get("oobCode"));
    const languageCode = cleanString(generatedUrl.searchParams.get("lang")) || "de";
    if (mode !== "resetPassword" || !oobCode) {
        firebase_functions_1.logger.error("Firebase password reset link is incomplete", {
            mode: mode || null,
            hasOobCode: oobCode.length > 0,
            path: generatedUrl.pathname,
            host: generatedUrl.hostname,
        });
        throw new Error("Der von Firebase erzeugte Passwort-Link ist unvollständig.");
    }
    const lumaResetUrl = new URL(`https://${lumaAuthDomain}/`);
    lumaResetUrl.searchParams.set("authAction", "passwordReset");
    lumaResetUrl.searchParams.set("mode", "resetPassword");
    lumaResetUrl.searchParams.set("oobCode", oobCode);
    lumaResetUrl.searchParams.set("lang", languageCode);
    return lumaResetUrl.toString();
}
function createLumaEmailVerificationUrl(firebaseActionLink) {
    let generatedUrl;
    try {
        generatedUrl = new URL(firebaseActionLink);
    }
    catch (error) {
        firebase_functions_1.logger.error("Firebase email verification link is not a valid URL", {
            error: String(error),
        });
        throw new Error("Der von Firebase erzeugte Bestätigungslink ist ungültig.");
    }
    const mode = cleanString(generatedUrl.searchParams.get("mode"));
    const oobCode = cleanString(generatedUrl.searchParams.get("oobCode"));
    const languageCode = cleanString(generatedUrl.searchParams.get("lang")) || "de";
    if (mode !== "verifyEmail" || !oobCode) {
        firebase_functions_1.logger.error("Firebase email verification link is incomplete", {
            mode: mode || null,
            hasOobCode: oobCode.length > 0,
            path: generatedUrl.pathname,
            host: generatedUrl.hostname,
        });
        throw new Error("Der von Firebase erzeugte Bestätigungslink ist unvollständig.");
    }
    const lumaVerificationUrl = new URL(`https://${lumaAuthDomain}/`);
    lumaVerificationUrl.searchParams.set("authAction", "emailVerification");
    lumaVerificationUrl.searchParams.set("mode", "verifyEmail");
    lumaVerificationUrl.searchParams.set("oobCode", oobCode);
    lumaVerificationUrl.searchParams.set("lang", languageCode);
    return lumaVerificationUrl.toString();
}
async function sendBrevoTransactionalEmail(input) {
    const apiKey = input.apiKey.trim();
    if (!apiKey) {
        throw new Error("BREVO_API_KEY ist leer.");
    }
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
            accept: "application/json",
            "api-key": apiKey,
            "content-type": "application/json",
        },
        body: JSON.stringify({
            sender: {
                name: input.senderName?.trim() || "Luma",
                email: lumaNoReplyEmail,
            },
            to: [
                {
                    email: input.recipientEmail,
                    name: input.recipientName,
                },
            ],
            replyTo: {
                name: input.replyToName?.trim() || "Luma Support",
                email: input.replyToEmail?.trim() || lumaSupportEmail,
            },
            subject: input.subject,
            htmlContent: input.htmlContent,
            textContent: input.textContent,
            tags: input.tags,
        }),
    });
    if (response.ok) {
        return;
    }
    const responseBody = await response.text();
    throw new Error(`Brevo API ${response.status}: ${responseBody.slice(0, 800)}`);
}
async function sendAccountDeletionConfirmationEmailSafely(input) {
    const recipientEmail = normalizeEmailAddress(input.recipientEmail);
    if (!isValidEmailAddress(recipientEmail)) {
        firebase_functions_1.logger.warn("ACCOUNT_DELETE_CONFIRMATION_EMAIL_SKIPPED", {
            userId: input.userId,
            reason: "missing-or-invalid-email",
        });
        return false;
    }
    const deletedAtLabel = new Intl.DateTimeFormat("de-DE", {
        dateStyle: "long",
        timeStyle: "short",
        timeZone: "Europe/Berlin",
    }).format(new Date());
    const maxAttempts = 3;
    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        try {
            await sendBrevoTransactionalEmail({
                apiKey: brevoApiKeySecret.value(),
                recipientEmail,
                recipientName: input.displayName,
                subject: "Dein Luma-Konto wurde gelöscht",
                htmlContent: createAccountDeletionConfirmationHtml({
                    displayName: input.displayName,
                    deletedAtLabel,
                }),
                textContent: createAccountDeletionConfirmationText({
                    displayName: input.displayName,
                    deletedAtLabel,
                }),
                tags: ["luma-account", "account-deletion-confirmation"],
                replyToEmail: lumaPrivacyEmail,
                replyToName: "Luma Datenschutz",
            });
            firebase_functions_1.logger.info("ACCOUNT_DELETE_CONFIRMATION_EMAIL_SENT", {
                userId: input.userId,
                emailHash: sha256Hex(recipientEmail),
                attempt,
            });
            return true;
        }
        catch (error) {
            firebase_functions_1.logger.error("ACCOUNT_DELETE_CONFIRMATION_EMAIL_FAILED", {
                userId: input.userId,
                emailHash: sha256Hex(recipientEmail),
                attempt,
                maxAttempts,
                error,
            });
            if (attempt < maxAttempts) {
                await new Promise((resolve) => {
                    setTimeout(resolve, attempt * 750);
                });
            }
        }
    }
    // Die bereits abgeschlossene Kontolöschung wird niemals zurückgerollt,
    // nur weil ein externer Maildienst vorübergehend nicht erreichbar ist.
    return false;
}
function createAccountDeletionConfirmationHtml(input) {
    const safeDisplayName = escapeHtml(input.displayName);
    const safeDeletedAtLabel = escapeHtml(input.deletedAtLabel);
    return `<!doctype html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="color-scheme" content="light dark">
      <title>Luma-Kontolöschung bestätigt</title>
    </head>
    <body style="margin:0;padding:0;background:#f7f4ef;font-family:Arial,Helvetica,sans-serif;color:#27231f;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f7f4ef;padding:28px 12px;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;background:#ffffff;border:1px solid #eee5da;border-radius:28px;overflow:hidden;box-shadow:0 16px 45px rgba(74,55,36,.10);">
              <tr>
                <td style="padding:34px 34px 22px;background:linear-gradient(135deg,#fff8ef 0%,#ffffff 58%,#f6eee4 100%);">
                  <div style="font-size:28px;font-weight:900;letter-spacing:-1px;color:#d97e29;">Luma</div>
                  <div style="margin-top:6px;font-size:13px;font-weight:700;color:#8b7867;">Bestätigung deiner Kontolöschung</div>
                </td>
              </tr>
              <tr>
                <td style="padding:12px 34px 34px;">
                  <h1 style="margin:0 0 16px;font-size:28px;line-height:1.15;letter-spacing:-.7px;color:#27231f;">Dein Konto wurde gelöscht</h1>
                  <p style="margin:0 0 14px;font-size:16px;line-height:1.65;color:#5f554c;">Hallo ${safeDisplayName},</p>
                  <p style="margin:0 0 20px;font-size:16px;line-height:1.65;color:#5f554c;">dein Luma-Konto wurde erfolgreich gelöscht. Die Löschung wurde am ${safeDeletedAtLabel} abgeschlossen.</p>
                  <div style="padding:16px 18px;background:#fff8ef;border:1px solid #f2dfca;border-radius:16px;font-size:13px;line-height:1.6;color:#766454;">Dein Profil und die unmittelbar mit deinem Konto verbundenen Daten wurden gemäß dem Luma-Löschprozess entfernt. Inhalte, die aus Sicherheits-, Moderations- oder gesetzlichen Gründen aufbewahrt werden dürfen oder müssen, werden nur im jeweils erforderlichen Umfang behandelt.</div>
                  <p style="margin:22px 0 0;font-size:14px;line-height:1.6;color:#5f554c;">Falls du diese Löschung nicht selbst veranlasst hast oder Fragen dazu hast, wende dich bitte an <a href="mailto:${lumaPrivacyEmail}" style="color:#c96f20;text-decoration:none;font-weight:700;">${lumaPrivacyEmail}</a>.</p>
                </td>
              </tr>
              <tr>
                <td style="padding:22px 34px;background:#2d2925;color:#d9d0c8;font-size:12px;line-height:1.6;">
                  Diese Nachricht wurde automatisch von Luma versendet. Antworten werden an <a href="mailto:${lumaPrivacyEmail}" style="color:#f2b777;text-decoration:none;">${lumaPrivacyEmail}</a> weitergeleitet.<br>
                  <a href="${lumaPublicUrl}" style="color:#f2b777;text-decoration:none;">luma-social.com</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>`;
}
function createAccountDeletionConfirmationText(input) {
    return [
        "Luma – Kontolöschung bestätigt",
        "",
        `Hallo ${input.displayName},`,
        "",
        "dein Luma-Konto wurde erfolgreich gelöscht.",
        `Abgeschlossen am ${input.deletedAtLabel}.`,
        "",
        "Dein Profil und die unmittelbar mit deinem Konto verbundenen Daten " +
            "wurden gemäß dem Luma-Löschprozess entfernt.",
        "",
        "Falls du diese Löschung nicht selbst veranlasst hast oder Fragen " +
            `dazu hast, schreibe an ${lumaPrivacyEmail}.`,
        "",
        lumaPublicUrl,
    ].join("\n");
}
function createPasswordResetHtml(input) {
    const safeDisplayName = escapeHtml(input.displayName);
    const safeResetUrl = escapeHtml(input.resetUrl);
    return `<!doctype html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="color-scheme" content="light dark">
      <title>Luma-Passwort zurücksetzen</title>
    </head>
    <body style="margin:0;padding:0;background:#f7f4ef;font-family:Arial,Helvetica,sans-serif;color:#27231f;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f7f4ef;padding:28px 12px;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;background:#ffffff;border:1px solid #eee5da;border-radius:28px;overflow:hidden;box-shadow:0 16px 45px rgba(74,55,36,.10);">
              <tr>
                <td style="padding:34px 34px 22px;background:linear-gradient(135deg,#fff8ef 0%,#ffffff 58%,#f6eee4 100%);">
                  <div style="font-size:28px;font-weight:900;letter-spacing:-1px;color:#d97e29;">Luma</div>
                  <div style="margin-top:6px;font-size:13px;font-weight:700;color:#8b7867;">Dein Konto. Sicher geschützt.</div>
                </td>
              </tr>
              <tr>
                <td style="padding:12px 34px 34px;">
                  <h1 style="margin:0 0 16px;font-size:28px;line-height:1.15;letter-spacing:-.7px;color:#27231f;">Passwort zurücksetzen</h1>
                  <p style="margin:0 0 14px;font-size:16px;line-height:1.65;color:#5f554c;">Hallo ${safeDisplayName},</p>
                  <p style="margin:0 0 24px;font-size:16px;line-height:1.65;color:#5f554c;">wir haben eine Anfrage erhalten, das Passwort deines Luma-Kontos zurückzusetzen. Über den folgenden Button kannst du ein neues Passwort festlegen.</p>
                  <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 26px;">
                    <tr>
                      <td bgcolor="#e58a2b" style="border-radius:16px;">
                        <a href="${safeResetUrl}" style="display:inline-block;padding:15px 24px;color:#ffffff;text-decoration:none;font-size:15px;font-weight:800;letter-spacing:.1px;">Passwort zurücksetzen</a>
                      </td>
                    </tr>
                  </table>
                  <div style="padding:16px 18px;background:#fff8ef;border:1px solid #f2dfca;border-radius:16px;font-size:13px;line-height:1.55;color:#766454;">Der Link ist zeitlich begrenzt. Falls du diese Anfrage nicht gestellt hast, kannst du diese E-Mail ignorieren. Dein bisheriges Passwort bleibt unverändert.</div>
                  <p style="margin:24px 0 8px;font-size:13px;line-height:1.55;color:#8b7d71;">Funktioniert der Button nicht? Kopiere diesen Link in deinen Browser:</p>
                  <p style="margin:0;word-break:break-all;font-size:12px;line-height:1.5;color:#a06a35;">${safeResetUrl}</p>
                </td>
              </tr>
              <tr>
                <td style="padding:22px 34px;background:#2d2925;color:#d9d0c8;font-size:12px;line-height:1.6;">
                  Diese Nachricht wurde automatisch von Luma versendet. Antworten werden an <a href="mailto:${lumaSupportEmail}" style="color:#f2b777;text-decoration:none;">${lumaSupportEmail}</a> weitergeleitet.<br>
                  <a href="${lumaPublicUrl}" style="color:#f2b777;text-decoration:none;">luma-social.com</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>`;
}
function createPasswordResetText(input) {
    return [
        "Luma – Passwort zurücksetzen",
        "",
        `Hallo ${input.displayName},`,
        "",
        "wir haben eine Anfrage erhalten, das Passwort deines " +
            "Luma-Kontos zurückzusetzen.",
        "",
        "Öffne diesen sicheren Link:",
        input.resetUrl,
        "",
        "Falls du diese Anfrage nicht gestellt hast, kannst du diese " +
            "E-Mail ignorieren. Dein bisheriges Passwort bleibt unverändert.",
        "",
        `Support: ${lumaSupportEmail}`,
        lumaPublicUrl,
    ].join("\n");
}
function createEmailVerificationHtml(input) {
    const safeDisplayName = escapeHtml(input.displayName);
    const safeVerificationUrl = escapeHtml(input.verificationUrl);
    return `<!doctype html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="color-scheme" content="light dark">
      <title>Luma-E-Mail-Adresse bestätigen</title>
    </head>
    <body style="margin:0;padding:0;background:#f7f4ef;font-family:Arial,Helvetica,sans-serif;color:#27231f;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f7f4ef;padding:28px 12px;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;background:#ffffff;border:1px solid #eee5da;border-radius:28px;overflow:hidden;box-shadow:0 16px 45px rgba(74,55,36,.10);">
              <tr>
                <td style="padding:34px 34px 22px;background:linear-gradient(135deg,#fff8ef 0%,#ffffff 58%,#f6eee4 100%);">
                  <div style="font-size:28px;font-weight:900;letter-spacing:-1px;color:#d97e29;">Luma</div>
                  <div style="margin-top:6px;font-size:13px;font-weight:700;color:#8b7867;">Dein Konto. Sicher bestätigt.</div>
                </td>
              </tr>
              <tr>
                <td style="padding:12px 34px 34px;">
                  <h1 style="margin:0 0 16px;font-size:28px;line-height:1.15;letter-spacing:-.7px;color:#27231f;">E-Mail-Adresse bestätigen</h1>
                  <p style="margin:0 0 14px;font-size:16px;line-height:1.65;color:#5f554c;">Hallo ${safeDisplayName},</p>
                  <p style="margin:0 0 24px;font-size:16px;line-height:1.65;color:#5f554c;">bestätige deine E-Mail-Adresse, damit dein Luma-Konto vollständig geschützt und einsatzbereit ist.</p>
                  <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 26px;">
                    <tr>
                      <td bgcolor="#e58a2b" style="border-radius:16px;">
                        <a href="${safeVerificationUrl}" style="display:inline-block;padding:15px 24px;color:#ffffff;text-decoration:none;font-size:15px;font-weight:800;letter-spacing:.1px;">E-Mail-Adresse bestätigen</a>
                      </td>
                    </tr>
                  </table>
                  <div style="padding:16px 18px;background:#fff8ef;border:1px solid #f2dfca;border-radius:16px;font-size:13px;line-height:1.55;color:#766454;">Der Link ist zeitlich begrenzt und kann nur einmal verwendet werden. Falls du kein Luma-Konto erstellt hast, kannst du diese E-Mail ignorieren.</div>
                  <p style="margin:24px 0 8px;font-size:13px;line-height:1.55;color:#8b7d71;">Funktioniert der Button nicht? Kopiere diesen Link in deinen Browser:</p>
                  <p style="margin:0;word-break:break-all;font-size:12px;line-height:1.5;color:#a06a35;">${safeVerificationUrl}</p>
                </td>
              </tr>
              <tr>
                <td style="padding:22px 34px;background:#2d2925;color:#d9d0c8;font-size:12px;line-height:1.6;">
                  Diese Nachricht wurde automatisch von Luma versendet. Antworten werden an <a href="mailto:${lumaSupportEmail}" style="color:#f2b777;text-decoration:none;">${lumaSupportEmail}</a> weitergeleitet.<br>
                  <a href="${lumaPublicUrl}" style="color:#f2b777;text-decoration:none;">luma-social.com</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>`;
}
function createEmailVerificationText(input) {
    return [
        "Luma – E-Mail-Adresse bestätigen",
        "",
        `Hallo ${input.displayName},`,
        "",
        "bestätige deine E-Mail-Adresse, damit dein Luma-Konto " +
            "vollständig geschützt und einsatzbereit ist.",
        "",
        "Öffne diesen sicheren Link:",
        input.verificationUrl,
        "",
        "Falls du kein Luma-Konto erstellt hast, kannst du diese " +
            "E-Mail ignorieren.",
        "",
        `Support: ${lumaSupportEmail}`,
        lumaPublicUrl,
    ].join("\n");
}
function escapeHtml(value) {
    return value
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}
function sha256Hex(value) {
    return crypto
        .createHash("sha256")
        .update(value, "utf8")
        .digest("hex");
}
const rememberedLoginCredentialsCollection = "remembered_login_credentials";
exports.registerRememberedLoginCredential = (0, https_1.onCall)(async (request) => {
    const userId = requireAuthenticatedUserId(request.auth?.uid);
    const credentialId = requireRememberedLoginToken(request.data?.credentialId, "credentialId", 24, 160);
    const secret = requireRememberedLoginToken(request.data?.secret, "secret", 32, 512);
    const installationId = requireRememberedLoginToken(request.data?.installationId, "installationId", 16, 160);
    const platform = cleanString(request.data?.platform).slice(0, 80) || "unknown";
    const credentialReference = db
        .collection(usersCollection)
        .doc(userId)
        .collection(rememberedLoginCredentialsCollection)
        .doc(credentialId);
    const existing = await credentialReference.get();
    const createdAt = existing.exists
        ? existing.data()?.createdAt ?? firestore_1.FieldValue.serverTimestamp()
        : firestore_1.FieldValue.serverTimestamp();
    await credentialReference.set({
        credentialId,
        userId,
        secretHash: rememberedLoginSecretHash({
            userId,
            credentialId,
            installationId,
            secret,
        }),
        installationId,
        platform,
        active: true,
        createdAt,
        registeredAt: firestore_1.FieldValue.serverTimestamp(),
        lastUsedAt: firestore_1.FieldValue.serverTimestamp(),
        revokedAt: null,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        success: true,
        credentialId,
    };
});
exports.exchangeRememberedLoginCredential = (0, https_1.onCall)(async (request) => {
    const userId = requireRememberedLoginToken(request.data?.userId, "userId", 1, 160);
    const credentialId = requireRememberedLoginToken(request.data?.credentialId, "credentialId", 24, 160);
    const secret = requireRememberedLoginToken(request.data?.secret, "secret", 32, 512);
    const installationId = requireRememberedLoginToken(request.data?.installationId, "installationId", 16, 160);
    const credentialReference = db
        .collection(usersCollection)
        .doc(userId)
        .collection(rememberedLoginCredentialsCollection)
        .doc(credentialId);
    const snapshot = await credentialReference.get();
    if (!snapshot.exists) {
        throw new https_1.HttpsError("not-found", "Die gespeicherte Geräteanmeldung wurde nicht gefunden.");
    }
    const data = snapshot.data() ?? {};
    if (data.active !== true || data.revokedAt != null) {
        throw new https_1.HttpsError("failed-precondition", "Die gespeicherte Geräteanmeldung wurde widerrufen.");
    }
    if (cleanString(data.installationId) !== installationId) {
        throw new https_1.HttpsError("permission-denied", "Die Gerätekennung stimmt nicht überein.");
    }
    const expectedHash = cleanString(data.secretHash);
    const suppliedHash = rememberedLoginSecretHash({
        userId,
        credentialId,
        installationId,
        secret,
    });
    if (!safeEqualHex(expectedHash, suppliedHash)) {
        throw new https_1.HttpsError("permission-denied", "Die gespeicherte Geräteanmeldung ist ungültig.");
    }
    const userRecord = await (0, auth_1.getAuth)().getUser(userId);
    if (userRecord.disabled) {
        throw new https_1.HttpsError("permission-denied", "Dieses Konto ist deaktiviert.");
    }
    const customToken = await (0, auth_1.getAuth)().createCustomToken(userId, {
        lumaRememberedLogin: true,
        rememberedCredentialId: credentialId,
    });
    await credentialReference.set({
        lastUsedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        success: true,
        customToken,
        userId,
    };
});
exports.revokeRememberedLoginCredential = (0, https_1.onCall)(async (request) => {
    const userId = requireRememberedLoginToken(request.data?.userId, "userId", 1, 160);
    const credentialId = requireRememberedLoginToken(request.data?.credentialId, "credentialId", 24, 160);
    const secret = requireRememberedLoginToken(request.data?.secret, "secret", 32, 512);
    const installationId = requireRememberedLoginToken(request.data?.installationId, "installationId", 16, 160);
    const credentialReference = db
        .collection(usersCollection)
        .doc(userId)
        .collection(rememberedLoginCredentialsCollection)
        .doc(credentialId);
    const snapshot = await credentialReference.get();
    if (!snapshot.exists) {
        return {
            success: true,
            alreadyRemoved: true,
        };
    }
    const data = snapshot.data() ?? {};
    const expectedHash = cleanString(data.secretHash);
    const suppliedHash = rememberedLoginSecretHash({
        userId,
        credentialId,
        installationId,
        secret,
    });
    if (cleanString(data.installationId) !== installationId ||
        !safeEqualHex(expectedHash, suppliedHash)) {
        throw new https_1.HttpsError("permission-denied", "Die Geräteanmeldung konnte nicht bestätigt werden.");
    }
    await credentialReference.set({
        active: false,
        secretHash: null,
        revokedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        success: true,
        alreadyRemoved: false,
    };
});
function rememberedLoginSecretHash(input) {
    return crypto
        .createHash("sha256")
        .update([
        "luma-remembered-login-v1",
        input.userId,
        input.credentialId,
        input.installationId,
        input.secret,
    ].join(":"), "utf8")
        .digest("hex");
}
function safeEqualHex(expected, supplied) {
    if (!/^[a-f0-9]{64}$/i.test(expected) ||
        !/^[a-f0-9]{64}$/i.test(supplied)) {
        return false;
    }
    const expectedBuffer = Buffer.from(expected, "hex");
    const suppliedBuffer = Buffer.from(supplied, "hex");
    return (expectedBuffer.length === suppliedBuffer.length &&
        crypto.timingSafeEqual(expectedBuffer, suppliedBuffer));
}
function requireRememberedLoginToken(value, fieldName, minLength, maxLength) {
    const cleaned = cleanString(value);
    if (cleaned.length < minLength ||
        cleaned.length > maxLength ||
        !/^[A-Za-z0-9._~-]+$/.test(cleaned)) {
        throw new https_1.HttpsError("invalid-argument", `${fieldName} ist ungültig.`);
    }
    return cleaned;
}
__exportStar(require("./luma_push"), exports);
var story_push_triggers_js_1 = require("./notifications/story_push_triggers.js");
Object.defineProperty(exports, "onStoryCreatedSendPush", { enumerable: true, get: function () { return story_push_triggers_js_1.onStoryCreatedSendPush; } });
var social_notification_triggers_js_1 = require("./notifications/social_notification_triggers.js");
Object.defineProperty(exports, "onPostCreated", { enumerable: true, get: function () { return social_notification_triggers_js_1.onPostCreated; } });
Object.defineProperty(exports, "onPostLikeCreated", { enumerable: true, get: function () { return social_notification_triggers_js_1.onPostLikeCreated; } });
Object.defineProperty(exports, "onPostLikeDeleted", { enumerable: true, get: function () { return social_notification_triggers_js_1.onPostLikeDeleted; } });
Object.defineProperty(exports, "onCommentCreated", { enumerable: true, get: function () { return social_notification_triggers_js_1.onCommentCreated; } });
Object.defineProperty(exports, "onCommentLikeCreated", { enumerable: true, get: function () { return social_notification_triggers_js_1.onCommentLikeCreated; } });
Object.defineProperty(exports, "onCommentLikeDeleted", { enumerable: true, get: function () { return social_notification_triggers_js_1.onCommentLikeDeleted; } });
Object.defineProperty(exports, "onFriendshipCreated", { enumerable: true, get: function () { return social_notification_triggers_js_1.onFriendshipCreated; } });
Object.defineProperty(exports, "onFriendshipUpdated", { enumerable: true, get: function () { return social_notification_triggers_js_1.onFriendshipUpdated; } });
const accountEnforcementAppealsCollection = "accountEnforcementAppeals";
exports.submitAccountEnforcementAppeal = (0, https_1.onCall)({
    secrets: [brevoApiKeySecret],
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (request) => {
    const enforcementId = cleanString(request.data?.enforcementId);
    const appealAccessToken = cleanString(request.data?.appealAccessToken);
    const statement = cleanString(request.data?.statement);
    const additionalInformation = cleanString(request.data?.additionalInformation);
    if (!enforcementId || !appealAccessToken) {
        throw new https_1.HttpsError("invalid-argument", "Die Kontomaßnahme kann nicht eindeutig zugeordnet werden.");
    }
    if (statement.length < 20 || statement.length > 4000) {
        throw new https_1.HttpsError("invalid-argument", "Die Widerspruchsbegründung muss zwischen 20 und 4000 Zeichen enthalten.");
    }
    if (additionalInformation.length > 4000) {
        throw new https_1.HttpsError("invalid-argument", "Zusätzliche Informationen dürfen höchstens 4000 Zeichen enthalten.");
    }
    const enforcementReference = db
        .collection("accountEnforcements")
        .doc(enforcementId);
    const appealReference = db
        .collection(accountEnforcementAppealsCollection)
        .doc(enforcementId);
    const initialEnforcementSnapshot = await enforcementReference.get();
    if (!initialEnforcementSnapshot.exists) {
        throw new https_1.HttpsError("not-found", "Diese Kontomaßnahme existiert nicht mehr.");
    }
    const initialEnforcementData = initialEnforcementSnapshot.data() ?? {};
    const expectedTokenHash = cleanString(initialEnforcementData.appealAccessTokenHash);
    const providedTokenHash = sha256Hex(appealAccessToken);
    if (!expectedTokenHash ||
        !crypto.timingSafeEqual(Buffer.from(expectedTokenHash, "utf8"), Buffer.from(providedTokenHash, "utf8"))) {
        throw new https_1.HttpsError("permission-denied", "Der sichere Zugriff auf diese Kontomaßnahme ist ungültig.");
    }
    if (initialEnforcementData.appealAllowed !== true) {
        throw new https_1.HttpsError("failed-precondition", "Für diese Maßnahme ist kein digitaler Widerspruch verfügbar.");
    }
    const userId = cleanString(initialEnforcementData.userId);
    if (!userId) {
        throw new https_1.HttpsError("failed-precondition", "Die Kontomaßnahme enthält keine gültige Nutzerzuordnung.");
    }
    const [userRecord, profileSnapshot] = await Promise.all([
        (0, auth_1.getAuth)().getUser(userId).catch(() => null),
        db.collection(usersCollection).doc(userId).get(),
    ]);
    const userDisplayName = cleanString(profileSnapshot.data()?.displayName) ||
        cleanString(userRecord?.displayName) ||
        "Luma-Mitglied";
    const recipientEmail = normalizeEmailAddress(userRecord?.email);
    const result = await db.runTransaction(async (transaction) => {
        const [enforcementSnapshot, existingAppealSnapshot,] = await Promise.all([
            transaction.get(enforcementReference),
            transaction.get(appealReference),
        ]);
        if (!enforcementSnapshot.exists) {
            throw new https_1.HttpsError("not-found", "Diese Kontomaßnahme existiert nicht mehr.");
        }
        const enforcementData = enforcementSnapshot.data() ?? {};
        const storedHash = cleanString(enforcementData.appealAccessTokenHash);
        const suppliedHash = sha256Hex(appealAccessToken);
        if (!storedHash ||
            !crypto.timingSafeEqual(Buffer.from(storedHash, "utf8"), Buffer.from(suppliedHash, "utf8"))) {
            throw new https_1.HttpsError("permission-denied", "Der sichere Zugriff auf diese Kontomaßnahme ist ungültig.");
        }
        if (existingAppealSnapshot.exists) {
            const existing = existingAppealSnapshot.data() ?? {};
            return {
                created: false,
                appealId: appealReference.id,
                ticketNumber: cleanString(existing.ticketNumber),
                status: cleanString(existing.status) || "submitted",
                stateUserId: cleanString(enforcementData.userId),
            };
        }
        const now = new Date();
        const ticketNumber = createAccountAppealTicketNumber(now);
        const caseId = cleanString(enforcementData.caseId);
        const caseNumber = cleanString(enforcementData.caseNumber);
        const enforcementType = cleanString(enforcementData.type);
        const publicReasonTitle = cleanString(enforcementData.publicReasonTitle);
        transaction.set(appealReference, {
            id: appealReference.id,
            ticketNumber,
            userId,
            userDisplayName,
            enforcementId,
            caseId,
            caseNumber,
            enforcementType,
            enforcementAction: cleanString(enforcementData.action),
            publicReasonTitle,
            statement,
            additionalInformation,
            status: "submitted",
            submittedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            reviewedAt: null,
            reviewedByAdminId: null,
            reviewedByAdminDisplayName: null,
            decision: null,
            adminDecisionNote: "",
            reducedDurationHours: null,
            schemaVersion: 1,
        });
        transaction.set(enforcementReference, {
            appealId: appealReference.id,
            appealTicketNumber: ticketNumber,
            appealStatus: "submitted",
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return {
            created: true,
            appealId: appealReference.id,
            ticketNumber,
            status: "submitted",
            stateUserId: userId,
        };
    });
    const stateReference = db
        .collection("accountEnforcementStates")
        .doc(result.stateUserId);
    const stateSnapshot = await stateReference.get();
    if (stateSnapshot.exists &&
        cleanString(stateSnapshot.data()?.enforcementId) === enforcementId) {
        await stateReference.set({
            appealId: result.appealId,
            appealTicketNumber: result.ticketNumber,
            appealStatus: result.status,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    if (result.created &&
        isValidEmailAddress(recipientEmail)) {
        try {
            await sendBrevoTransactionalEmail({
                apiKey: brevoApiKeySecret.value(),
                recipientEmail,
                recipientName: userDisplayName,
                senderName: "Luma Support",
                subject: `Wir haben deinen Widerspruch erhalten – ${result.ticketNumber}`,
                htmlContent: createAccountAppealReceivedHtml({
                    displayName: userDisplayName,
                    ticketNumber: result.ticketNumber,
                    caseNumber: cleanString(initialEnforcementData.caseNumber),
                }),
                textContent: createAccountAppealReceivedText({
                    displayName: userDisplayName,
                    ticketNumber: result.ticketNumber,
                    caseNumber: cleanString(initialEnforcementData.caseNumber),
                }),
                tags: [
                    "luma-support",
                    "account-appeal",
                ],
                replyToEmail: lumaSupportEmail,
                replyToName: "Luma Support",
            });
        }
        catch (error) {
            firebase_functions_1.logger.error("ACCOUNT_APPEAL_CONFIRMATION_EMAIL_FAILED", {
                enforcementId,
                ticketNumber: result.ticketNumber,
                error,
            });
        }
    }
    firebase_functions_1.logger.info("ACCOUNT_APPEAL_SUBMITTED", {
        enforcementId,
        appealId: result.appealId,
        ticketNumber: result.ticketNumber,
        created: result.created,
    });
    return {
        success: true,
        appealId: result.appealId,
        ticketNumber: result.ticketNumber,
        status: result.status,
        alreadyExists: !result.created,
    };
});
exports.reviewAccountEnforcementAppeal = (0, https_1.onCall)({
    secrets: [brevoApiKeySecret],
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (request) => {
    const actor = await requireEnforcementAdminActor({
        userId: request.auth?.uid,
        token: request.auth?.token,
    });
    if (actor.role !== "superAdmin" &&
        actor.role !== "admin") {
        throw new https_1.HttpsError("permission-denied", "Deine Adminrolle darf Widersprüche nicht entscheiden.");
    }
    const appealId = cleanString(request.data?.appealId);
    const decision = normalizeAccountAppealDecision(request.data?.decision);
    const adminNote = cleanString(request.data?.adminNote);
    const reducedDurationHours = readPositiveNumber(request.data?.reducedDurationHours);
    if (!appealId) {
        throw new https_1.HttpsError("invalid-argument", "appealId fehlt.");
    }
    if (decision !== "underReview" &&
        (adminNote.length < 10 ||
            adminNote.length > 4000)) {
        throw new https_1.HttpsError("invalid-argument", "Eine abschließende Entscheidung benötigt eine interne Dokumentation zwischen 10 und 4000 Zeichen.");
    }
    const appealReference = db
        .collection(accountEnforcementAppealsCollection)
        .doc(appealId);
    const appealSnapshot = await appealReference.get();
    if (!appealSnapshot.exists) {
        throw new https_1.HttpsError("not-found", "Dieser Widerspruch existiert nicht.");
    }
    const appealData = appealSnapshot.data() ?? {};
    const currentStatus = cleanString(appealData.status);
    if (currentStatus === "upheld" ||
        currentStatus === "lifted" ||
        currentStatus === "reduced") {
        throw new https_1.HttpsError("failed-precondition", "Dieser Widerspruch wurde bereits abschließend entschieden.");
    }
    if (decision === "underReview") {
        await appealReference.set({
            status: "underReview",
            reviewedByAdminId: actor.userId,
            reviewedByAdminDisplayName: actor.displayName,
            reviewStartedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        const stateUserId = cleanString(appealData.userId);
        if (stateUserId) {
            const stateReference = db
                .collection("accountEnforcementStates")
                .doc(stateUserId);
            const stateSnapshot = await stateReference.get();
            if (stateSnapshot.exists &&
                cleanString(stateSnapshot.data()?.enforcementId) ===
                    cleanString(appealData.enforcementId)) {
                await stateReference.set({
                    appealStatus: "underReview",
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }
        return {
            success: true,
            status: "underReview",
        };
    }
    const enforcementId = cleanString(appealData.enforcementId);
    const userId = cleanString(appealData.userId);
    if (!enforcementId || !userId) {
        throw new https_1.HttpsError("failed-precondition", "Der Widerspruch ist unvollständig.");
    }
    const enforcementReference = db
        .collection("accountEnforcements")
        .doc(enforcementId);
    const stateReference = db
        .collection("accountEnforcementStates")
        .doc(userId);
    const auditReference = db.collection("adminAuditLogs").doc();
    const now = new Date();
    const finalResult = await db.runTransaction(async (transaction) => {
        const [freshAppealSnapshot, enforcementSnapshot, stateSnapshot,] = await Promise.all([
            transaction.get(appealReference),
            transaction.get(enforcementReference),
            transaction.get(stateReference),
        ]);
        if (!freshAppealSnapshot.exists ||
            !enforcementSnapshot.exists) {
            throw new https_1.HttpsError("not-found", "Der Widerspruch oder die zugehörige Kontomaßnahme existiert nicht mehr.");
        }
        const freshAppeal = freshAppealSnapshot.data() ?? {};
        const freshStatus = cleanString(freshAppeal.status);
        if (freshStatus === "upheld" ||
            freshStatus === "lifted" ||
            freshStatus === "reduced") {
            throw new https_1.HttpsError("failed-precondition", "Dieser Widerspruch wurde bereits entschieden.");
        }
        const enforcementData = enforcementSnapshot.data() ?? {};
        const enforcementType = cleanString(enforcementData.type);
        let appealStatus = "upheld";
        let resultingType = enforcementType;
        let resultingIsActive = enforcementData.isActive === true;
        let resultingExpiresAt = enforcementData.expiresAt ?? null;
        if (decision === "lift") {
            appealStatus = "lifted";
            resultingType = "none";
            resultingIsActive = false;
            resultingExpiresAt = null;
            transaction.set(enforcementReference, {
                isActive: false,
                status: "liftedOnAppeal",
                liftedAt: firestore_1.FieldValue.serverTimestamp(),
                liftedByAdminId: actor.userId,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            if (stateSnapshot.exists &&
                cleanString(stateSnapshot.data()?.enforcementId) === enforcementId) {
                transaction.set(stateReference, {
                    isActive: false,
                    type: "none",
                    appealStatus: "lifted",
                    appealId,
                    appealTicketNumber: cleanString(freshAppeal.ticketNumber),
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }
        else if (decision === "reduce") {
            if (enforcementType !==
                "permanentSuspension" &&
                enforcementType !==
                    "temporarySuspension") {
                throw new https_1.HttpsError("failed-precondition", "Diese Kontomaßnahme kann nicht zeitlich reduziert werden.");
            }
            const allowed = new Set([1, 24, 72, 168, 720]);
            if (!allowed.has(reducedDurationHours)) {
                throw new https_1.HttpsError("invalid-argument", "Diese reduzierte Sperrdauer ist nicht freigegeben.");
            }
            const newExpiresAt = new Date(now.getTime() +
                reducedDurationHours *
                    60 *
                    60 *
                    1000);
            const existingExpiresAt = firestoreDateValue(enforcementData.expiresAt);
            if (enforcementType ===
                "temporarySuspension" &&
                existingExpiresAt !== null &&
                newExpiresAt.getTime() >=
                    existingExpiresAt.getTime()) {
                throw new https_1.HttpsError("failed-precondition", "Die neue Dauer muss kürzer als die bestehende Sperre sein.");
            }
            appealStatus = "reduced";
            resultingType =
                "temporarySuspension";
            resultingIsActive = true;
            resultingExpiresAt =
                newExpiresAt;
            transaction.set(enforcementReference, {
                action: "temporarySuspension",
                type: "temporarySuspension",
                status: "active",
                isActive: true,
                expiresAt: newExpiresAt,
                reducedOnAppeal: true,
                reducedDurationHours,
                reducedAt: firestore_1.FieldValue.serverTimestamp(),
                reducedByAdminId: actor.userId,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            if (stateSnapshot.exists &&
                cleanString(stateSnapshot.data()?.enforcementId) === enforcementId) {
                transaction.set(stateReference, {
                    action: "temporarySuspension",
                    type: "temporarySuspension",
                    isActive: true,
                    expiresAt: newExpiresAt,
                    appealStatus: "reduced",
                    appealId,
                    appealTicketNumber: cleanString(freshAppeal.ticketNumber),
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }
        else {
            if (stateSnapshot.exists &&
                cleanString(stateSnapshot.data()?.enforcementId) === enforcementId) {
                transaction.set(stateReference, {
                    appealStatus: "upheld",
                    appealId,
                    appealTicketNumber: cleanString(freshAppeal.ticketNumber),
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }
        transaction.set(appealReference, {
            status: appealStatus,
            decision,
            adminDecisionNote: adminNote,
            reviewedAt: firestore_1.FieldValue.serverTimestamp(),
            reviewedByAdminId: actor.userId,
            reviewedByAdminDisplayName: actor.displayName,
            reducedDurationHours: decision === "reduce"
                ? reducedDurationHours
                : null,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(enforcementReference, {
            appealId,
            appealTicketNumber: cleanString(freshAppeal.ticketNumber),
            appealStatus,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(auditReference, {
            id: auditReference.id,
            actorAdminId: actor.userId,
            actorDisplayName: actor.displayName,
            actorRole: actor.role,
            targetUserId: userId,
            action: "accountEnforcementAppealDecided",
            appealId,
            ticketNumber: cleanString(freshAppeal.ticketNumber),
            enforcementId,
            caseId: cleanString(freshAppeal.caseId),
            caseNumber: cleanString(freshAppeal.caseNumber),
            decision,
            appealStatus,
            adminDecisionNote: adminNote,
            reducedDurationHours: decision === "reduce"
                ? reducedDurationHours
                : null,
            resultingState: {
                type: resultingType,
                isActive: resultingIsActive,
                expiresAt: resultingExpiresAt,
            },
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            schemaVersion: 1,
        });
        const caseId = cleanString(freshAppeal.caseId);
        if (caseId) {
            transaction.set(db
                .collection("moderationCases")
                .doc(caseId), {
                appealId,
                appealStatus,
                appealDecision: decision,
                appealReviewedAt: firestore_1.FieldValue.serverTimestamp(),
                appealReviewedByAdminId: actor.userId,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        return {
            status: appealStatus,
            ticketNumber: cleanString(freshAppeal.ticketNumber),
            caseNumber: cleanString(freshAppeal.caseNumber),
            publicReasonTitle: cleanString(freshAppeal.publicReasonTitle),
            resultingExpiresAt: resultingExpiresAt instanceof Date
                ? resultingExpiresAt
                : firestoreDateValue(resultingExpiresAt),
        };
    });
    const [userRecord, profileSnapshot] = await Promise.all([
        (0, auth_1.getAuth)().getUser(userId).catch(() => null),
        db.collection(usersCollection).doc(userId).get(),
    ]);
    const recipientEmail = normalizeEmailAddress(userRecord?.email);
    const displayName = cleanString(profileSnapshot.data()?.displayName) ||
        cleanString(userRecord?.displayName) ||
        "Luma-Mitglied";
    if (isValidEmailAddress(recipientEmail)) {
        try {
            await sendBrevoTransactionalEmail({
                apiKey: brevoApiKeySecret.value(),
                recipientEmail,
                recipientName: displayName,
                senderName: "Luma Support",
                subject: `Entscheidung zu deinem Widerspruch – ${finalResult.ticketNumber}`,
                htmlContent: createAccountAppealDecisionHtml({
                    displayName,
                    ticketNumber: finalResult.ticketNumber,
                    caseNumber: finalResult.caseNumber,
                    status: finalResult.status,
                    expiresAt: finalResult.resultingExpiresAt,
                }),
                textContent: createAccountAppealDecisionText({
                    displayName,
                    ticketNumber: finalResult.ticketNumber,
                    caseNumber: finalResult.caseNumber,
                    status: finalResult.status,
                    expiresAt: finalResult.resultingExpiresAt,
                }),
                tags: [
                    "luma-support",
                    "account-appeal-decision",
                ],
                replyToEmail: lumaSupportEmail,
                replyToName: "Luma Support",
            });
        }
        catch (error) {
            firebase_functions_1.logger.error("ACCOUNT_APPEAL_DECISION_EMAIL_FAILED", {
                appealId,
                ticketNumber: finalResult.ticketNumber,
                error,
            });
        }
    }
    firebase_functions_1.logger.info("ACCOUNT_APPEAL_DECIDED", {
        appealId,
        enforcementId,
        userId,
        actorUserId: actor.userId,
        decision,
        status: finalResult.status,
    });
    return {
        success: true,
        status: finalResult.status,
        ticketNumber: finalResult.ticketNumber,
    };
});
function normalizeAccountAppealDecision(value) {
    const decision = cleanString(value);
    if (decision === "underReview" ||
        decision === "uphold" ||
        decision === "lift" ||
        decision === "reduce") {
        return decision;
    }
    throw new https_1.HttpsError("invalid-argument", "Ungültige Widerspruchsentscheidung.");
}
function createAccountAppealTicketNumber(now) {
    const suffix = crypto
        .randomBytes(5)
        .toString("hex")
        .toUpperCase();
    return `LUMA-AP-${now.getUTCFullYear()}-${suffix}`;
}
function firestoreDateValue(value) {
    if (value instanceof Date) {
        return value;
    }
    if (value &&
        typeof value === "object" &&
        "toDate" in value &&
        typeof value.toDate === "function") {
        return value.toDate();
    }
    return null;
}
function createAccountAppealReceivedHtml(input) {
    return `
    <div style="font-family:Arial,sans-serif;max-width:640px;margin:0 auto;color:#17191f">
      <h1 style="font-size:26px">Wir haben deinen Widerspruch erhalten</h1>
      <p>Hallo ${escapeHtml(input.displayName)},</p>
      <p>dein Antrag auf Überprüfung einer Luma-Kontomaßnahme wurde erfolgreich erfasst.</p>
      <div style="padding:18px;border:1px solid #e4e6eb;border-radius:14px;margin:22px 0">
        <strong>Ticketnummer</strong><br>
        ${escapeHtml(input.ticketNumber)}<br><br>
        <strong>Zugehöriger Fall</strong><br>
        ${escapeHtml(input.caseNumber)}
      </div>
      <p>Während der Prüfung bleibt die aktuell verhängte Maßnahme grundsätzlich bestehen.</p>
      <p>Sobald eine Entscheidung getroffen wurde, informieren wir dich per E-Mail.</p>
      <p>Viele Grüße<br><strong>Luma Support</strong></p>
    </div>
  `;
}
function createAccountAppealReceivedText(input) {
    return [
        `Hallo ${input.displayName},`,
        "",
        "dein Antrag auf Überprüfung einer Luma-Kontomaßnahme wurde erfolgreich erfasst.",
        "",
        `Ticketnummer: ${input.ticketNumber}`,
        `Zugehöriger Fall: ${input.caseNumber}`,
        "",
        "Während der Prüfung bleibt die aktuell verhängte Maßnahme grundsätzlich bestehen.",
        "Sobald eine Entscheidung getroffen wurde, informieren wir dich per E-Mail.",
        "",
        "Viele Grüße",
        "Luma Support",
    ].join("\n");
}
function createAccountAppealDecisionHtml(input) {
    const decisionText = accountAppealDecisionPublicText(input.status, input.expiresAt);
    return `
    <div style="font-family:Arial,sans-serif;max-width:640px;margin:0 auto;color:#17191f">
      <h1 style="font-size:26px">Entscheidung zu deinem Widerspruch</h1>
      <p>Hallo ${escapeHtml(input.displayName)},</p>
      <p>wir haben deinen Antrag auf Überprüfung abgeschlossen.</p>
      <div style="padding:18px;border:1px solid #e4e6eb;border-radius:14px;margin:22px 0">
        <strong>Ticketnummer</strong><br>
        ${escapeHtml(input.ticketNumber)}<br><br>
        <strong>Fallnummer</strong><br>
        ${escapeHtml(input.caseNumber)}<br><br>
        <strong>Entscheidung</strong><br>
        ${escapeHtml(decisionText)}
      </div>
      <p>Bei Rückfragen kannst du dich unter Angabe deiner Ticketnummer an ${escapeHtml(lumaSupportEmail)} wenden.</p>
      <p>Viele Grüße<br><strong>Luma Support</strong></p>
    </div>
  `;
}
function createAccountAppealDecisionText(input) {
    return [
        `Hallo ${input.displayName},`,
        "",
        "wir haben deinen Antrag auf Überprüfung abgeschlossen.",
        "",
        `Ticketnummer: ${input.ticketNumber}`,
        `Fallnummer: ${input.caseNumber}`,
        `Entscheidung: ${accountAppealDecisionPublicText(input.status, input.expiresAt)}`,
        "",
        `Bei Rückfragen kannst du dich unter Angabe deiner Ticketnummer an ${lumaSupportEmail} wenden.`,
        "",
        "Viele Grüße",
        "Luma Support",
    ].join("\n");
}
function accountAppealDecisionPublicText(status, expiresAt) {
    switch (status) {
        case "lifted":
            return "Die Kontomaßnahme wurde aufgehoben.";
        case "reduced":
            return expiresAt === null
                ? "Die Kontomaßnahme wurde reduziert."
                : `Die Kontomaßnahme wurde reduziert und gilt nun bis ${formatLumaDateTime(expiresAt)}.`;
        case "upheld":
        default:
            return "Die ursprüngliche Kontomaßnahme wurde nach erneuter Prüfung bestätigt.";
    }
}
function formatLumaDateTime(value) {
    return new Intl.DateTimeFormat("de-DE", {
        timeZone: "Europe/Berlin",
        dateStyle: "medium",
        timeStyle: "short",
    }).format(value);
}
// =====================================================================
// MANUELLES AUFHEBEN EINER ACCOUNT-ENFORCEMENT-MASSNAHME
// =====================================================================
exports.liftAccountEnforcement = (0, https_1.onCall)({
    secrets: [brevoApiKeySecret],
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (request) => {
    const actor = await requireEnforcementAdminActor({
        userId: request.auth?.uid,
        token: request.auth?.token,
    });
    if (actor.role !== "superAdmin" &&
        actor.role !== "admin") {
        throw new https_1.HttpsError("permission-denied", "Deine Adminrolle darf Kontomaßnahmen nicht aufheben.");
    }
    const enforcementId = cleanString(request.data?.enforcementId);
    const internalNote = cleanString(request.data?.internalNote);
    if (!enforcementId) {
        throw new https_1.HttpsError("invalid-argument", "enforcementId fehlt.");
    }
    if (internalNote.length < 10 ||
        internalNote.length > 4000) {
        throw new https_1.HttpsError("invalid-argument", "Die interne Begründung muss zwischen 10 und 4000 Zeichen enthalten.");
    }
    const enforcementReference = db
        .collection("accountEnforcements")
        .doc(enforcementId);
    const enforcementSnapshot = await enforcementReference.get();
    if (!enforcementSnapshot.exists) {
        throw new https_1.HttpsError("not-found", "Diese Kontomaßnahme existiert nicht.");
    }
    const enforcementData = enforcementSnapshot.data() ?? {};
    const userId = cleanString(enforcementData.userId);
    const caseId = cleanString(enforcementData.caseId);
    const caseNumber = cleanString(enforcementData.caseNumber);
    if (!userId) {
        throw new https_1.HttpsError("failed-precondition", "Die Kontomaßnahme besitzt keine gültige Nutzerzuordnung.");
    }
    const stateReference = db
        .collection("accountEnforcementStates")
        .doc(userId);
    const auditReference = db.collection("adminAuditLogs").doc();
    await db.runTransaction(async (transaction) => {
        const [freshEnforcementSnapshot, stateSnapshot,] = await Promise.all([
            transaction.get(enforcementReference),
            transaction.get(stateReference),
        ]);
        if (!freshEnforcementSnapshot.exists) {
            throw new https_1.HttpsError("not-found", "Diese Kontomaßnahme existiert nicht mehr.");
        }
        const freshEnforcement = freshEnforcementSnapshot.data() ?? {};
        const stateData = stateSnapshot.exists
            ? stateSnapshot.data() ?? {}
            : {};
        const currentStateEnforcementId = cleanString(stateData.enforcementId);
        const currentStateActive = stateData.isActive === true;
        // accountEnforcementStates/{userId} ist die verbindliche Quelle
        // für den AKTUELLEN Kontostatus.
        //
        // Die historische Maßnahmenakte darf nach Appeals oder anderen
        // Entscheidungen einen abweichenden Status besitzen. Dadurch darf
        // eine spätere administrative Entsperrung niemals verhindert werden.
        if (!stateSnapshot.exists ||
            !currentStateActive) {
            throw new https_1.HttpsError("failed-precondition", "Für dieses Konto besteht derzeit keine aktive Kontosperre.");
        }
        if (currentStateEnforcementId !== enforcementId) {
            throw new https_1.HttpsError("failed-precondition", "Diese Maßnahmenakte ist nicht mehr die aktuell aktive Kontosperre des Nutzers.");
        }
        const previousType = cleanString(stateData.type) ||
            cleanString(freshEnforcement.type);
        const previousStatus = cleanString(freshEnforcement.status);
        transaction.set(enforcementReference, {
            isActive: false,
            status: "liftedManually",
            liftedAt: firestore_1.FieldValue.serverTimestamp(),
            liftedByAdminId: actor.userId,
            liftedByAdminDisplayName: actor.displayName,
            liftInternalNote: internalNote,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(stateReference, {
            isActive: false,
            type: "none",
            liftedAt: firestore_1.FieldValue.serverTimestamp(),
            liftedByAdminId: actor.userId,
            liftedByAdminDisplayName: actor.displayName,
            liftInternalNote: internalNote,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        if (caseId) {
            transaction.set(db
                .collection("moderationCases")
                .doc(caseId), {
                enforcementStatus: "liftedManually",
                enforcementLiftedAt: firestore_1.FieldValue.serverTimestamp(),
                enforcementLiftedByAdminId: actor.userId,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        transaction.set(auditReference, {
            id: auditReference.id,
            actorAdminId: actor.userId,
            actorDisplayName: actor.displayName,
            actorRole: actor.role,
            targetUserId: userId,
            action: "accountEnforcementLifted",
            enforcementId,
            caseId,
            caseNumber,
            previousState: {
                type: previousType,
                status: previousStatus,
                isActive: true,
                expiresAt: stateData.expiresAt ??
                    freshEnforcement.expiresAt ??
                    null,
                appealStatus: cleanString(stateData.appealStatus) || null,
            },
            newState: {
                type: "none",
                status: "liftedManually",
                isActive: false,
                expiresAt: null,
            },
            internalNote,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            schemaVersion: 1,
        });
    });
    const [userRecord, profileSnapshot] = await Promise.all([
        (0, auth_1.getAuth)().getUser(userId).catch(() => null),
        db.collection(usersCollection).doc(userId).get(),
    ]);
    const recipientEmail = normalizeEmailAddress(userRecord?.email);
    const displayName = cleanString(profileSnapshot.data()?.displayName) ||
        cleanString(userRecord?.displayName) ||
        "Luma-Mitglied";
    if (isValidEmailAddress(recipientEmail)) {
        try {
            await sendBrevoTransactionalEmail({
                apiKey: brevoApiKeySecret.value(),
                recipientEmail,
                recipientName: displayName,
                senderName: "Luma Support",
                subject: `Deine Luma-Kontomaßnahme wurde aufgehoben – ${caseNumber}`,
                htmlContent: `
            <div style="font-family:Arial,sans-serif;max-width:640px;margin:0 auto;color:#17191f">
              <h1 style="font-size:26px">Deine Kontomaßnahme wurde aufgehoben</h1>
              <p>Hallo ${escapeHtml(displayName)},</p>
              <p>die zu deinem Luma-Konto bestehende Kontomaßnahme wurde nach erneuter administrativer Prüfung aufgehoben.</p>
              <div style="padding:18px;border:1px solid #e4e6eb;border-radius:14px;margin:22px 0">
                <strong>Fallnummer</strong><br>
                ${escapeHtml(caseNumber)}
              </div>
              <p>Du kannst dich wieder regulär bei Luma anmelden.</p>
              <p>Viele Grüße<br><strong>Luma Support</strong></p>
            </div>
          `,
                textContent: [
                    `Hallo ${displayName},`,
                    "",
                    "die zu deinem Luma-Konto bestehende Kontomaßnahme wurde nach erneuter administrativer Prüfung aufgehoben.",
                    "",
                    `Fallnummer: ${caseNumber}`,
                    "",
                    "Du kannst dich wieder regulär bei Luma anmelden.",
                    "",
                    "Viele Grüße",
                    "Luma Support",
                ].join("\n"),
                tags: [
                    "luma-support",
                    "account-enforcement-lifted",
                ],
                replyToEmail: lumaSupportEmail,
                replyToName: "Luma Support",
            });
        }
        catch (error) {
            firebase_functions_1.logger.error("ACCOUNT_ENFORCEMENT_LIFT_EMAIL_FAILED", {
                enforcementId,
                userId,
                caseNumber,
                error,
            });
        }
    }
    firebase_functions_1.logger.info("ACCOUNT_ENFORCEMENT_LIFTED", {
        enforcementId,
        userId,
        caseNumber,
        actorUserId: actor.userId,
    });
    return {
        success: true,
        enforcementId,
        userId,
        caseNumber,
        status: "liftedManually",
    };
});
exports.checkAccountEnforcementStatus = (0, https_1.onCall)({
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (request) => {
    const enforcementId = cleanString(request.data?.enforcementId);
    const appealAccessToken = cleanString(request.data?.appealAccessToken);
    if (!enforcementId || !appealAccessToken) {
        throw new https_1.HttpsError("invalid-argument", "Die Kontomaßnahme kann nicht sicher zugeordnet werden.");
    }
    const enforcementReference = db
        .collection("accountEnforcements")
        .doc(enforcementId);
    const snapshot = await enforcementReference.get();
    if (!snapshot.exists) {
        return {
            success: true,
            enforcementId,
            isActive: false,
            type: "none",
            expiresAt: null,
        };
    }
    const data = snapshot.data() ?? {};
    const expectedHash = cleanString(data.appealAccessTokenHash);
    const providedHash = sha256Hex(appealAccessToken);
    if (!expectedHash ||
        expectedHash.length !== providedHash.length ||
        !crypto.timingSafeEqual(Buffer.from(expectedHash, "utf8"), Buffer.from(providedHash, "utf8"))) {
        throw new https_1.HttpsError("permission-denied", "Der sichere Zugriff auf diese Kontomaßnahme ist ungültig.");
    }
    const expiresAt = firestoreDateValue(data.expiresAt);
    const expired = expiresAt !== null &&
        new Date().getTime() > expiresAt.getTime();
    const isActive = data.isActive === true && !expired;
    return {
        success: true,
        enforcementId,
        isActive,
        type: isActive
            ? cleanString(data.type)
            : "none",
        status: cleanString(data.status),
        expiresAt: expiresAt === null
            ? null
            : expiresAt.toISOString(),
    };
});
//# sourceMappingURL=index.js.map