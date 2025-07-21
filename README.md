# Org Limit Tracking Framework

This framework allows users to schedule snapshots of org limits and configure alerts on it.

## Disclaimer

> [!IMPORTANT]
> Org Limit Tracking Framework is not an official Salesforce product, it has not been officially tested or documented by Salesforce.

## How Do You Configure Org Limit Tracking?

The configuration is based on two objects:

- **OrgSnapshot__c**: Stores the org limit snapshot defined by the frequency of the scheduled job.
- **OrgSnapshotAlert__c**: Configures alerts for users when a particular threshold is reached.

You can customize if the alert must be sent to a user or public group by email and/or by custom notification.

> [!IMPORTANT]
> **Prerequisite**: At least one `OrgSnapshotAlert__c` record must be configured for the batch job to create any snapshots. If no alert records exist, no snapshots will be saved to the database.

### Permission Sets

Two Permission Sets are defined for this framework:

- **OrgSnapshotUser**: Gives read access to `OrgSnapshot__c`
- **OrgSnapshotAdmin**: Gives read and write access to `OrgSnapshot__c`, `OrgSnapshotAlert__c`, and related batch classes.

## Running the OrgSnapshotBatch in Full or Partial Mode

The batch class `OrgSnapshotBatch` can be executed in **two modes**:

- **Full Mode (`isPartial = false`)** → Saves **all** org limits to `OrgSnapshot__c`.
- **Partial Mode (`isPartial = true`)** → Saves **only** limits that have a matching `OrgSnapshotAlert__c`.

### Example: Execute Batch Manually

```apex
// Full Mode: Save all org limits
Database.executeBatch(new OrgSnapshotBatch(false));

// Partial Mode: Save only limits with alerts configured
Database.executeBatch(new OrgSnapshotBatch(true));
```

### Example: Schedule the Batch

```apex
// Run the batch every day at midnight
String cronExp = '0 0 0 * * ?';
System.schedule('Daily OrgSnapshotBatch', cronExp, new OrgSnapshotBatch(false));
```

👉 For scheduling every **15 minutes**, create multiple cron jobs.

### Example: Create an Alert Configuration

Before running the batch, you need to create at least one `OrgSnapshotAlert__c` record. Here's an example for monitoring `DailyDeliveredPlatformEvents` with a 90% threshold:

```apex
// Create an alert for DailyDeliveredPlatformEvents at 90% threshold
OrgSnapshotAlert__c alert = new OrgSnapshotAlert__c(
    Name = 'Daily Platform Events Alert',
    Limit__c = 'DailyDeliveredPlatformEvents',
    Threshold__c = 90.0,
    User__c = UserInfo.getUserId(), // Alert current user
    Email__c = 'admin@company.com', // Optional: CC email address
    SendCustomNotification__c = true, // Send custom notifications
    NotificationInterval__c = 60 // Wait 60 minutes between alerts
);
insert alert;
```

You can also create alerts for other org limits such as:
- `DataStorageMB`
- `FileStorageMB`
- `DailyApiRequests`
- `HourlyTimeBasedWorkflow`
- And many others...

## How To Schedule Org Limit Tracking?

You can schedule the `OrgSnapshotBatchSchedulable` class to execute periodically.

> [!WARNING]
> For schedules that are less than a 1-hour period, you will have to create different cron jobs, ie for 15 minutes jobs:

```apex
System.schedule('Daily OrgSnapshotBatch 0', '0 0 * * * ?', new OrgSnapshotBatch(false));
System.schedule('Daily OrgSnapshotBatch 15', '0 15 * * * ?', new OrgSnapshotBatch(false));
System.schedule('Daily OrgSnapshotBatch 30', '0 30 * * * ?', new OrgSnapshotBatch(false));
System.schedule('Daily OrgSnapshotBatch 45', '0 45 * * * ?', new OrgSnapshotBatch(false));
```

These schedules will count against the **100 scheduled Apex jobs limit**. More details in the [Salesforce documentation](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm#:~:text=Apex%20Scheduler%20Limits,equal%20to%20%E2%80%9CScheduled%20Apex%E2%80%9D.).

### Example: Custom Notification & Email alert

<img width="451" alt="Custom Notification" src="https://github.com/user-attachments/assets/c3059004-4ac4-478c-87da-c7f1dfaec2bd" />


<img width="490" alt="Email alert" src="https://github.com/user-attachments/assets/db6a8fd8-6b87-44e9-abd9-6107935148ff" />

## Dashboard and Reporting

### Daily Delivered Platform Events Dashboard

A comprehensive dashboard is included to monitor the evolution of your `DailyDeliveredPlatformEvents` org limit usage over time. The dashboard provides:

- **Line charts** showing usage trends and limit utilization percentage
- **Bar charts** for recent daily usage patterns
- **Key metrics** including average usage, peak usage, and current limits
- **Detailed data table** for precise inspection

**Access the dashboard**: Navigate to the "Org Snapshot" app → Dashboards tab → "Daily Delivered Platform Events - Monitoring Dashboard"

For detailed documentation, see [DASHBOARD_README.md](DASHBOARD_README.md).

### Notification Interval

To prevent alert spam, you can configure a notification interval for each alert. This setting determines the minimum time that must pass between consecutive alerts for the same limit.

- **NotificationInterval__c**: Time in minutes between two notifications for the same limit
- If not set (null), alerts will be sent every time the threshold is reached
- If set, alerts will only be sent if enough time has passed since the last alert
- The interval is checked for both email notifications and custom notifications


### Records Purge

Based on the frequency of the schedule you define, the framework can create lots of records. You can manage `OrgSnapshot__c` purge with the framework [SObject Purge Framework](https://github.com/tprouvot/purge-sobject).

## Deploy to Salesforce

Checkout the repo and deploy it with `sfdx`:

```sh
sf project deploy start -p force-app
```

Use GitHub Salesforce Deploy Tool:

[<img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png" />](https://githubsfdeploy.herokuapp.com/?owner=tprouvot&repo=org-limit-tracking&ref=main)

