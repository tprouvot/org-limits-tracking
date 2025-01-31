/**
 * @description This batch fetches org limits and saves it in a custom object for tracking.
 */
public with sharing class OrgSnapshotBatch implements Database.Batchable<SObject> {

	private final static String TITLE = 'Org Limit Alert: Threshold Reached';
	private final static String BODY = 'Alert! Your alert threshold is reached for the following limits:\n\n';
	private final static String CUSTOM_NOTIF_DEV_NAME = 'OrgSnapshotAlert';
	private static CustomNotificationType notificationType;

	private Boolean isPartial;

	/**
	 * @description     Constructor to generate a partial snapshot based on the OrgSnapshotAlert__c configured
	 * @param isPartial
	 */
	public OrgSnapshotBatch(Boolean isPartial) {
		this.isPartial = isPartial;
	}

	/**
	 * @description     Default constructor to generate a full snapshot for all OrgLimits
	 */
	public OrgSnapshotBatch() {
		this.isPartial = false;
	}

	/**
	 * @description Returns the QueryLocator to fecth the OrgSnapshotAlert__c
	 * @param BC
	 * @return      `Database.QueryLocator`
	 */
	public Database.QueryLocator start(Database.BatchableContext BC) {
		return System.Database.getQueryLocator([
			SELECT Limit__c, Threshold__c, LastAlertSentDate__c, Email__c, User__r.Email, SendCustomNotification__c
			FROM OrgSnapshotAlert__c ORDER BY User__c ASC
		]);
	}

	/**
	 * @description Send the alerts if the percentage is reached
	 * @param BC
	 * @param scope
	 */
	public void execute(Database.BatchableContext BC, List<OrgSnapshotAlert__c> scope) {
		Map<String, System.OrgLimit> limitsMap = OrgLimits.getMap();
		Map<String, OrgSnapshotAlert__c> alertsMap = getAlertMap(scope);
		List<OrgSnapshot__c> snapshots = new List<OrgSnapshot__c>();

		// Group alerts by User for a single email per user
		Map<Id, List<String>> userAlertMessages = new Map<Id, List<String>>();
		Map<Id, String> userEmails = new Map<Id, String>();
		Set<String> userIdsToNotify = new Set<String>();

		for (String key : limitsMap.keySet()) {
			System.OrgLimit orgLimit = limitsMap.get(key);

			// Save snapshots based on isPartial flag
			setOrgSnapshotToSave(snapshots, alertsMap.containsKey(key), orgLimit);

			for (OrgSnapshotAlert__c alert : scope) {
				if (alert.Limit__c == key) {
					Decimal percent = getLimitPercentage(orgLimit);
					if (percent >= alert.Threshold__c) {
						// Aggregate alerts per user
						if (!userAlertMessages.containsKey(alert.User__c)) {
							userAlertMessages.put(alert.User__c, new List<String>());
						}
						userAlertMessages.get(alert.User__c).add(buildAlertEmailBody(alert.Threshold__c, percent, orgLimit));
						userEmails.put(alert.User__c, alert.Email__c);

						if (alert.SendCustomNotification__c) {
							userIdsToNotify.add(alert.User__c);
						}
					}
				}
			}
		}

		// Send one email per user
		List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
		for (Id userId : userAlertMessages.keySet()) {
			String emailBody = BODY + String.join(userAlertMessages.get(userId), '\n');
			emailsToSend.add(createEmail(userId, userEmails.get(userId), emailBody));
		}
		Messaging.sendEmail(emailsToSend);

		// Send custom notifications if needed
		if (!userIdsToNotify.isEmpty()) {
			notifyUsers(userAlertMessages);
		}
		insert snapshots;
	}

	public void finish(Database.BatchableContext BC) {}

	private void setOrgSnapshotToSave(List<OrgSnapshot__c> snapshots, Boolean hasAlert, System.OrgLimit orgLimit) {
		if (!this.isPartial || hasAlert) {
			snapshots.add(new OrgSnapshot__c(
				Name = orgLimit.getName(),
				Value__c = orgLimit.getValue(),
				Limit__c = orgLimit.getLimit()
			));
		}
	}

	private Map<String, OrgSnapshotAlert__c> getAlertMap(List<OrgSnapshotAlert__c> alerts) {
		Map<String, OrgSnapshotAlert__c> alertMap = new Map<String, OrgSnapshotAlert__c>();
		for (OrgSnapshotAlert__c alert : alerts) {
			alertMap.put(alert.Limit__c, alert);
		}
		return alertMap;
	}

	private String buildAlertEmailBody(Decimal alertPercentage, Decimal percent, System.OrgLimit orgLimit) {
		return '- ' + orgLimit.getName() + ': ' + percent.stripTrailingZeros() + '%, ' +
			(orgLimit.getLimit() - orgLimit.getValue()) + '/' + orgLimit.getLimit() +
			' (Threshold = ' + alertPercentage.stripTrailingZeros() + '%)';
	}

	private Messaging.SingleEmailMessage createEmail(Id userId, String emailAddress, String emailBody) {
		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		if (String.isNotBlank(emailAddress)) {
			email.setCcAddresses(new String[]{emailAddress});
		}
		email.setSaveAsActivity(false);
		email.setTargetObjectId(userId);
		email.setSubject(TITLE);
		email.setPlainTextBody(emailBody);
		return email;
	}

	private Decimal getLimitPercentage(System.OrgLimit orgLimit) {
		Decimal percent = ((Decimal) orgLimit.getValue() / (Decimal) orgLimit.getLimit()) * 100;
		return percent.setScale(2, RoundingMode.HALF_UP);
	}

	private void notifyUsers(Map<Id, List<String>> userAlertMessages) {
		CustomNotificationType notificationType = getNotificationType();

		for (Id userId : userAlertMessages.keySet()) {
			String notificationBody = BODY + String.join(userAlertMessages.get(userId), '\n');

			Messaging.CustomNotification notification = new Messaging.CustomNotification();
			notification.setTitle(TITLE);
			notification.setBody(notificationBody);
			notification.setNotificationTypeId(notificationType.Id);
			notification.setTargetPageRef('{ type: "standard__app", attributes:{appTarget: "c__OrgSnapshot", attributes: {"objectApiName":"OrgSnapshot__c",actionName: "list"}}}');
			notification.send(new Set<String>{userId});
		}
	}

	private static CustomNotificationType getNotificationType() {
		if (notificationType == null) {
			notificationType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName=:CUSTOM_NOTIF_DEV_NAME LIMIT 1];
		}
		return notificationType;
	}
}
