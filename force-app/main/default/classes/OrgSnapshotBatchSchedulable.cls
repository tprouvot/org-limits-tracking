/**
 * @description This class is used to schedule OrgSnapshotBatch class
 */
public with sharing class OrgSnapshotBatchSchedulable implements Schedulable {
	/**
	 * @description Execute OrgSnapshotBatch
	 * @param sc    SchedulableContext
	 */
	public void execute(SchedulableContext sc) {
		Database.executeBatch(new OrgSnapshotBatch());
	}
}