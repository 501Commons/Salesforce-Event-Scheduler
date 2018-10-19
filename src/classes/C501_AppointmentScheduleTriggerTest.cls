@isTest
public with sharing class C501_AppointmentScheduleTriggerTest {

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

		C501_AppointmentScheduleTriggerHelper.get().updateAppointmentSchedule(new List<C501_Appointment_Schedule__c> { appointmentSchedule }, null);
	}
}