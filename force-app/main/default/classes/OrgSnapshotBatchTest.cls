/**
 * @description Test class for OrgSnapshotBatch.
 */
@isTest
private class OrgSnapshotBatchTest {

	@testSetup
	static void setupTestData() {
		// Create test users
		User testUser = new User(
			Alias = 'test1', Email = 'user@orsnapshot.com', EmailEncodingKey = 'UTF-8',
			LastName = 'User1', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
			ProfileId = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id,
			TimeZoneSidKey = 'America/Los_Angeles', Username = 'user@orsnapshot.com'
		);
		insert testUser;

		// Create OrgSnapshotAlert__c record
		OrgSnapshotAlert__c alert = new OrgSnapshotAlert__c(
			Limit__c = 'DataStorageMB', Threshold__c = 1, User__c = testUser.Id, Email__c = 'user2@example.com', SendCustomNotification__c = true
		);
		insert alert;
	}

	@isTest
	static void testBatchExecutionFullSave() {
		Test.startTest();
		OrgSnapshotBatch batch = new OrgSnapshotBatch(false); // Full save
		Database.executeBatch(batch);
		Test.stopTest();

		// Validate that OrgSnapshot__c records were saved
		List<OrgSnapshot__c> snapshots = [SELECT Id FROM OrgSnapshot__c];
		System.assert(snapshots.size() > 0, 'Expected OrgSnapshot__c records to be created.');
	}

	@isTest
	static void testBatchExecutionPartialSave() {
		Test.startTest();
		OrgSnapshotBatch batch = new OrgSnapshotBatch(true); // Partial save
		Database.executeBatch(batch);
		Test.stopTest();

		// Validate that OrgSnapshot__c records were saved (only those with matching alerts)
		List<OrgSnapshot__c> snapshots = [SELECT Id FROM OrgSnapshot__c];
		System.assert(snapshots.size() > 0, 'Expected OrgSnapshot__c records to be created for matching alerts.');
	}

	@isTest
	static void orgSnapshotBatchScheduleTest(){
		Datetime tomorrow = System.today().addDays(1);
		String cron = '0 0 0 ' + tomorrow.day() + ' ' + tomorrow.month() + ' ?';
		String jobId = System.schedule('TestSchedule', cron , new OrgSnapshotBatch());

		// Get the information from the CronTrigger API object
		CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];

		// Verify the expressions are the same
		System.assertEquals(cron, ct.CronExpression, 'CronExpression should be equals');

		// Verify the job has not run
		System.assertEquals(0, ct.TimesTriggered, 'Job should not run');
	}
}