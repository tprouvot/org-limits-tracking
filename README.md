# Org Limit Tracking Framework

This framework allow users to schedule snapshots of org limits and configure alerts on it.

## Disclaimer

Org Limit Tracking Framework is not an official Salesforce product, it has not been officially tested or documented by Salesforce.

## How Do You Configure Org Limit Tracking ?

The configuration is based on two objects:

- OrgSnapshot__c : used to store the org limit snapshot defined by the frequency of the scheduled job.
- OrgSnapshotAlert__c : used to configure the alerts by users when a particular threshold is reached.

You can customize if the alert must be sent to a User by email and by custom notification.

Two PermissionSet are defined for this framework:

- OrgSnapshotUser: gives read access to OrgSnapshot__c
- OrgSnapshotAdmin: gives read and write access to OrgSnapshot__c, OrgSnapshotAlert__c objects and related batch classes.


## How To Schedule Org Limit Tracking?

You can schedule OrgSnapshotBatchSchedulable class to execute periodically.

:::warning
For schedules that are less than 1h period, you will have to create different cron jobs
:::
ie

`0 0 * * * ?`
`0 15 * * * ?`
`0 30 * * * ?`
`0 45 * * * ?`

Those schedules will count against the 100 scheduled Apex jobs, more details in the [documentation](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm#:~:text=Apex%20Scheduler%20Limits,equal%20to%20%E2%80%9CScheduled%20Apex%E2%80%9D.)

### Records Purge

Based on the frequency of the schedule you will define, the framework can create lots of records.
You can manage OrgSnapshot__c purge with the framework [SObject Purge Framework](https://github.com/tprouvot/purge-sobject)

## Deploy to Salesforce

Checkout the repo and deploy it with sfdx:
```sh
sf project deploy start -p force-app
```

Use GitHub Salesforce Deploy Tool:

[<img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png" />](https://githubsfdeploy.herokuapp.com/?owner=tprouvot&repo=org-limit-tracking&ref=main)
