@isTest
public with sharing class C501_AppointmentScheduleTriggerHelperTest {

	@isTest
	private static void testUpdateAppointmentScheduleTrigger() {

		C501_Appointment_Schedule__c appointmentSchedule = new C501_Appointment_Schedule__c(
			Name = 'C501_Appointment_Schedule__c.Name'
		);
		insert appointmentSchedule;

		C501_Appointment__c appointment = new C501_Appointment__c(
			Name = 'C501_Appointment__c.Name'
		);
		insert appointment;

		C501_TriggerHelper triggerHelper = new C501_TriggerHelper();
		triggerHelper.updateAppointmentSchedule(new sList<C501_Appointment_Schedule__c> { appointmentSchedule }, null);
	}
}