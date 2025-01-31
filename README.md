# Org Limit Tracking Framework

This framework allows users to schedule snapshots of org limits and configure alerts on it.

## Disclaimer

> [!IMPORTANT]
> Org Limit Tracking Framework is not an official Salesforce product, it has not been officially tested or documented by Salesforce.

## How Do You Configure Org Limit Tracking?

The configuration is based on two objects:

- **OrgSnapshot__c**: Stores the org limit snapshot defined by the frequency of the scheduled job.
- **OrgSnapshotAlert__c**: Configures alerts for users when a particular threshold is reached.

You can customize if the alert must be sent to a user by email and/or by custom notification.

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

### Example: Using the Schedulable Class

`OrgSnapshotBatchSchedulable` can be used to automate execution:

```apex
System.schedule('Org Snapshot Scheduler', '0 0 * * * ?', new OrgSnapshotBatchSchedulable());
```

👉 For scheduling every **15 minutes**, create multiple cron jobs.

## How To Schedule Org Limit Tracking?

You can schedule the `OrgSnapshotBatchSchedulable` class to execute periodically.

> [!WARNING]
> For schedules that are less than a 1-hour period, you will have to create different cron jobs:

```
0 0 * * * ?
0 15 * * * ?
0 30 * * * ?
0 45 * * * ?
```

These schedules will count against the **100 scheduled Apex jobs limit**. More details in the [Salesforce documentation](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm#:~:text=Apex%20Scheduler%20Limits,equal%20to%20%E2%80%9CScheduled%20Apex%E2%80%9D.).

### Records Purge

Based on the frequency of the schedule you define, the framework can create lots of records. You can manage `OrgSnapshot__c` purge with the framework [SObject Purge Framework](https://github.com/tprouvot/purge-sobject).

## Deploy to Salesforce

Checkout the repo and deploy it with `sfdx`:

```sh
sf project deploy start -p force-app
```

Use GitHub Salesforce Deploy Tool:

[<img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png" />](https://githubsfdeploy.herokuapp.com/?owner=tprouvot&repo=org-limit-tracking&ref=main)

