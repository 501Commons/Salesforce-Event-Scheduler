public with sharing class C501_AppointmentScheduleTriggerHelper {

	public class InvalidParameterValueException extends Exception {}

	// only need one instance of this class per transaction
	private static C501_AppointmentScheduleTriggerHelper instance;
	public static C501_AppointmentScheduleTriggerHelper get() {
		if (instance == null) instance = new C501_AppointmentScheduleTriggerHelper();
		return instance;
	}
	
	public void updateAppointmentSchedule( List<C501_Appointment_Schedule__c> appointmentScheduleList, map<id, C501_Appointment_Schedule__c> oldMap) {

		if (appointmentScheduleList == null || appointmentScheduleList.isEmpty()) {
			return;
		}

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//
		List<C501_Appointment__c> allAppointments = [
			SELECT Id, Appointment_Schedule__c, Enable__c, Maximum_Scheduled_Appointments__c
			FROM C501_Appointment__c
			WHERE Enable__c = true AND Date__c >= :system.today()];

		// Step1: Disable all related Appointments
		Map<String, C501_Appointment__c> allAppointmentsByName = new Map<String, C501_Appointment__c>();
		Map<Id, C501_Appointment__c> updateAppointments = new Map<Id, C501_Appointment__c>();
		for ( C501_Appointment_Schedule__c appointmentSchedule :appointmentScheduleList ) {

			try {
				// Walk thru all appointments to get all related to the appointment schedule
				for ( C501_Appointment__c appointment :allAppointments) {

					if (appointment.Appointment_Schedule__c == appointmentSchedule.Id) {
						appointment.Enable__c = false;
						updateAppointments.put(appointment.Id, appointment);
					}

					// Build ByName map for processing later
	        		allAppointmentsByName.put(appointment.Name, appointment);
				}
			}
			catch (Exception e) {
				appointmentSchedule.AddError('updateAppointmentSchedule::Exception - ' + String.valueOf(e));
				continue;
			}
		}

		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		if (!updateAppointments.isEmpty()) {
			update updateAppointments.values();
		}

		updateAppointments.clear();
		Map<String, C501_Appointment__c> insertAppointments = new Map<String, C501_Appointment__c>();

		// Step2: Update all related Appointments and create new Appointments
		for ( C501_Appointment_Schedule__c appointmentSchedule :appointmentScheduleList ) {

			if (!appointmentSchedule.Enable__c) {
				continue;
			}

			try {
// DEBUG
				Boolean updated = false;
				Boolean inserted = false;

				DateTime appointmentDateTime = appointmentSchedule.Scheduled_Start_Date_Time__c;
				Time appointmentTime = appointmentDateTime.time();
				while (appointmentTime < appointmentSchedule.Scheduled_End_Time__c) {
					String appointmentTimeDisplay = String.valueOf(appointmentTime.hour())
							+ ':'
							+ String.valueOf(appointmentTime.minute())
							+ ' AM';
					if (appointmentTime.hour() > 12) {
						appointmentTimeDisplay = String.valueOf(appointmentTime.hour() - 12)
							+ ':'
							+ String.valueOf(appointmentTime.minute())
							+ ' PM';
					}
					C501_Appointment__c appointment = new C501_Appointment__c();
					appointment.Name = appointmentSchedule.Scheduled_Start_Date_Time__c.format('yyyy-MM-dd')
						+ ' - '
						+ appointmentTimeDisplay;

					if (allAppointmentsByName.containsKey(appointment.Name)) {
						C501_Appointment__c appointmentUpdate = allAppointmentsByName.remove(appointment.Name);
						appointmentUpdate.Enable__c = true;
						appointmentUpdate.Maximum_Scheduled_Appointments__c = appointmentSchedule.Number_Appointments_per_15_min_interval__c;

						updateAppointments.put(appointmentUpdate.Id, appointmentUpdate);

						updated = true;
					}
					else {
						appointment.Name_Unique__c = appointment.Name;
						appointment.Appointment_Schedule__c = appointmentSchedule.Id;
						appointment.Available_Time__c = appointmentDateTime;
						appointment.Date__c = appointmentSchedule.Scheduled_Start_Date_Time__c.date();
						appointment.Time__c = appointmentTimeDisplay;
						appointment.Enable__c = true;
						appointment.Maximum_Scheduled_Appointments__c = appointmentSchedule.Number_Appointments_per_15_min_interval__c;

						insertAppointments.put(appointment.Name, appointment);

						inserted = true;
					}

					// Increment by 15 minutes
					appointmentDateTime.addMinutes(15);
					appointmentTime = appointmentDateTime.time();

// DEBUG
					if (updated && inserted) {
						break;
					}
				}
			}
			catch (Exception e) {
				appointmentSchedule.AddError('updateAppointmentSchedule::Exception - ' + String.valueOf(e));
				continue;
			}
		}

		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		if (!updateAppointments.isEmpty()) {
			update updateAppointments.values();
		}
		if (!insertAppointments.isEmpty()) {
			insert insertAppointments.values();
		}
	}
}
