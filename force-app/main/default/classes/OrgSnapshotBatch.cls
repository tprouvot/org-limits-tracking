/**
 * @description This batch fetches org limits and saves it in a custom object for tracking.
 */
public with sharing class OrgSnapshotBatch implements Database.Batchable<SObject>, Schedulable {

	private final static String TITLE = 'Org Limit Alert: Threshold Reached';
	private final static String BODY = 'Alert! Your alert threshold is reached for the following limit:\n\n';
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
			SELECT Name, Limit__c, Threshold__c, LastAlertSentDate__c, Email__c, User__r.Email,
				SendCustomNotification__c, Group__c, NotificationInterval__c
			FROM OrgSnapshotAlert__c ORDER BY User__c ASC
		]);
	}

	/**
	 * @description Scheduled execution of OrgSnapshotBatch
	 * @param sc    SchedulableContext
	 */
	public void execute(SchedulableContext sc) {
		Database.executeBatch(new OrgSnapshotBatch());
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
		List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
		Set<String> userIdsToNotify = new Set<String>();
		List<OrgSnapshotAlert__c> alertsToUpdate = new List<OrgSnapshotAlert__c>();

		for (String key : limitsMap.keySet()) {
			System.OrgLimit orgLimit = limitsMap.get(key);

			// Save snapshots based on isPartial flag
			setOrgSnapshotToSave(snapshots, alertsMap.containsKey(key), orgLimit);

			for (OrgSnapshotAlert__c alert : scope) {
				if (alert.Limit__c == key) {
					Decimal percent = getLimitPercentage(orgLimit);
					if (percent >= alert.Threshold__c) {
						if (shouldSendAlert(alert)) {
							String emailBody = BODY + buildAlertEmailBody(alert.Threshold__c, percent, orgLimit);
							processNotificationRecipients(alert, emailBody, emailsToSend, userIdsToNotify, orgLimit.getName());

							// Update LastAlertSentDate__c
							alert.LastAlertSentDate__c = System.now();
							alertsToUpdate.add(alert);
						}
					}
				}
			}
		}

		// Send emails
		if (!emailsToSend.isEmpty()) {
			Messaging.sendEmail(emailsToSend);
		}

		// Send custom notifications if needed
		if (!userIdsToNotify.isEmpty()) {
			notifyUsers(userIdsToNotify, limitsMap, alertsMap);
		}

		insert snapshots;

		// Update LastAlertSentDate__c for alerts that were sent
		if (!alertsToUpdate.isEmpty()) {
			update alertsToUpdate;
		}
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

	private Messaging.SingleEmailMessage createEmail(Id userId, String emailAddress, String emailBody, String limitName) {
		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		if (String.isNotBlank(emailAddress)) {
			email.setCcAddresses(new String[]{emailAddress});
		}
		email.setSaveAsActivity(false);
		email.setTargetObjectId(userId);
		email.setSubject(TITLE + ' ' + limitName);
		email.setPlainTextBody(emailBody);
		return email;
	}

	private Decimal getLimitPercentage(System.OrgLimit orgLimit) {
		Decimal percent = ((Decimal) orgLimit.getValue() / (Decimal) orgLimit.getLimit()) * 100;
		return percent.setScale(2, RoundingMode.HALF_UP);
	}

	private void notifyUsers(Set<String> userIdsToNotify, Map<String, System.OrgLimit> limitsMap, Map<String, OrgSnapshotAlert__c> alertsMap) {
		CustomNotificationType notificationType = getNotificationType();

		for (String userId : userIdsToNotify) {
			for (String key : limitsMap.keySet()) {
				System.OrgLimit orgLimit = limitsMap.get(key);
				OrgSnapshotAlert__c alert = alertsMap.get(key);

				if (alert != null) {
					Decimal percent = getLimitPercentage(orgLimit);
					if (percent >= alert.Threshold__c && shouldSendAlert(alert)) {
						String notificationBody = BODY + buildAlertEmailBody(alert.Threshold__c, percent, orgLimit);

						Messaging.CustomNotification notification = new Messaging.CustomNotification();
						notification.setTitle(TITLE);
						notification.setBody(notificationBody);
						notification.setNotificationTypeId(notificationType.Id);
						notification.setTargetPageRef('{ type: "standard__app", attributes:{appTarget: "c__OrgSnapshot", attributes: {"objectApiName":"OrgSnapshot__c",actionName: "list"}}}');
						notification.send(new Set<String>{userId});
					}
				}
			}
		}
	}

	private static CustomNotificationType getNotificationType() {
		if (notificationType == null) {
			notificationType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName=:CUSTOM_NOTIF_DEV_NAME LIMIT 1];
		}
		return notificationType;
	}

	/**
	 * @description Process notification recipients for an alert
	 * @param alert The alert configuration
	 * @param emailBody The email body to send
	 * @param emailsToSend List of emails to be sent
	 * @param userIdsToNotify Set of user IDs to receive notifications
	 */
	private void processNotificationRecipients(
		OrgSnapshotAlert__c alert,
		String emailBody,
		List<Messaging.SingleEmailMessage> emailsToSend,
		Set<String> userIdsToNotify,
		String limitName
	) {
		Set<String> recipientIds = new Set<String>();

		// Get recipients based on alert configuration
		if (String.isNotBlank(alert.Group__c)) {
			recipientIds.addAll(getGroupMemberIds(alert.Group__c));
		} else if (String.isNotBlank(alert.User__c)) {
			recipientIds.add(alert.User__c);
		}

		// Process each recipient
		Boolean isFirstRecipient = true;
		for (String userId : recipientIds) {
			// Add CC email only for the first recipient to avoid hitting email limits
			String ccEmail = isFirstRecipient ? alert.Email__c : null;
			emailsToSend.add(createEmail(userId, ccEmail, emailBody, limitName));
			if (alert.SendCustomNotification__c) {
				userIdsToNotify.add(userId);
			}
			isFirstRecipient = false;
		}
	}

	/**
	 * @description Get all user IDs from a public group
	 * @param groupDevName The developer name of the public group
	 * @return Set<String> Set of user IDs that are members of the group
	 */
	private Set<String> getGroupMemberIds(String groupDevName) {
		Set<String> userIds = new Set<String>();
		if (String.isBlank(groupDevName)) {
			return userIds;
		}

		// Query for the group members
		for (GroupMember member : [
			SELECT UserOrGroupId
			FROM GroupMember
			WHERE Group.DeveloperName = :groupDevName
		]) {
			userIds.add(member.UserOrGroupId);
		}
		return userIds;
	}

	/**
	 * @description Determines if an alert should be sent based on the notification interval
	 * @param alert The alert configuration to check
	 * @return Boolean True if the alert should be sent, false otherwise
	 */
	private Boolean shouldSendAlert(OrgSnapshotAlert__c alert) {
		if (alert.NotificationInterval__c == null || alert.LastAlertSentDate__c == null) {
			return true;
		}

		Long millisecondsSinceLastAlert = System.now().getTime() - alert.LastAlertSentDate__c.getTime();
		Integer minutesSinceLastAlert = Integer.valueOf(millisecondsSinceLastAlert / (1000 * 60));
		return minutesSinceLastAlert >= alert.NotificationInterval__c;
	}
}
