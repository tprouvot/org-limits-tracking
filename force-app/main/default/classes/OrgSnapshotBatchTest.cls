/**
 * @description Test class for OrgSnapshotBatch.
 */
@isTest
private class OrgSnapshotBatchTest {

	private static final String TEST_GROUP_NAME = 'OrgSnapshotTestGroup';
	private static final String ADMIN_USERNAME = 'admin@orsnapshot.com';

	@testSetup
	static void setupTestData() {
		// Create test users
		List<User> users = new List<User>{
			new User(
				Alias = 'test1', Email = 'user@orsnapshot.com', EmailEncodingKey = 'UTF-8',
				LastName = 'User1', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
				ProfileId = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1].Id,
				TimeZoneSidKey = 'America/Los_Angeles', Username = 'user@orsnapshot.com'
			),
			new User(
				Alias = 'admin', Email = ADMIN_USERNAME, EmailEncodingKey = 'UTF-8',
				LastName = 'Admin', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
				ProfileId = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1].Id,
				TimeZoneSidKey = 'America/Los_Angeles', Username = ADMIN_USERNAME
			)
		};
		insert users;

		// Assign permission set to admin user
		PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'OrgSnapshotAdmin' LIMIT 1];
		PermissionSetAssignment psa = new PermissionSetAssignment(
			AssigneeId = users[1].Id,
			PermissionSetId = ps.Id
		);
		insert psa;

		System.runAs(users[1]) {
			// Create a public group
			Group testGroup = new Group(
				Name = TEST_GROUP_NAME,
				DeveloperName = TEST_GROUP_NAME,
				Type = 'Regular'
			);
			insert testGroup;

			// Add user to the group
			GroupMember member = new GroupMember(
				GroupId = testGroup.Id,
				UserOrGroupId = users[0].Id
			);
			insert member;

			// Create OrgSnapshotAlert__c records
			List<OrgSnapshotAlert__c> alerts = new List<OrgSnapshotAlert__c>{
				new OrgSnapshotAlert__c(
					Limit__c = 'DataStorageMB',
					Threshold__c = 1,
					User__c = users[0].Id,
					SendCustomNotification__c = true
				),
				new OrgSnapshotAlert__c(
					Limit__c = 'FileStorageMB',
					Threshold__c = 0.01,
					Group__c = TEST_GROUP_NAME,
					NotificationInterval__c = 60 // 60 minutes refresh interval
				)
			};
			insert alerts;
		}
	}

	@isTest
	static void testBatchExecutionFullSave() {
		User admin = [SELECT Id FROM User WHERE Username = :ADMIN_USERNAME LIMIT 1];
		System.runAs(admin) {
			Test.startTest();
			OrgSnapshotBatch batch = new OrgSnapshotBatch(false); // Full save
			Database.executeBatch(batch);
			Test.stopTest();

			// Validate that OrgSnapshot__c records were saved
			List<OrgSnapshot__c> snapshots = [SELECT Id FROM OrgSnapshot__c];
			System.assert(snapshots.size() > 0, 'Expected OrgSnapshot__c records to be created.');
		}
	}

	@isTest
	static void testBatchExecutionPartialSave() {
		User admin = [SELECT Id FROM User WHERE Username = :ADMIN_USERNAME LIMIT 1];
		System.runAs(admin) {
			Test.startTest();
			OrgSnapshotBatch batch = new OrgSnapshotBatch(true); // Partial save
			Database.executeBatch(batch);
			Test.stopTest();

			// Validate that OrgSnapshot__c records were saved (only those with matching alerts)
			List<OrgSnapshot__c> snapshots = [SELECT Id FROM OrgSnapshot__c];
			System.assert(snapshots.size() > 0, 'Expected OrgSnapshot__c records to be created for matching alerts.');
		}
	}

	@isTest
	static void orgSnapshotBatchScheduleTest() {
		User admin = [SELECT Id FROM User WHERE Username = :ADMIN_USERNAME LIMIT 1];
		System.runAs(admin) {
			Datetime tomorrow = System.today().addDays(1);
			String cron = '0 0 0 ' + tomorrow.day() + ' ' + tomorrow.month() + ' ?';
			String jobId = System.schedule('TestSchedule', cron, new OrgSnapshotBatch());

			// Get the information from the CronTrigger API object
			CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];

			// Verify the expressions are the same
			System.assertEquals(cron, ct.CronExpression, 'CronExpression should be equals');

			// Verify the job has not run
			System.assertEquals(0, ct.TimesTriggered, 'Job should not run');
		}
	}
}