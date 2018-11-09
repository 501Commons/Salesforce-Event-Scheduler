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
		Date dateToday = system.today();
		List<C501_Appointment__c> allAppointments = [
			SELECT Id, Name, Appointment_Schedule__c, Enable__c, Enable_Previous__c, Maximum_Scheduled_Appointments__c
			FROM C501_Appointment__c
			WHERE Date__c >= :dateToday];

		// Process all appointments to make sure appointments have the right parent
		List<C501_Appointment_Schedule__c> allAppointmentSchedules = [
			SELECT Id, Enable__c, Scheduled_Start_Date_Time__c, Scheduled_End_Time__c, Range_Of_Recurrence_End_By__c, Days_of_Week__c, Weekly_Occurrence__c,
				Number_Appointments_per_15_min_interval__c, Senior_Only_Appointments_60_and_over__c
			FROM C501_Appointment_Schedule__c
			WHERE Enable__c = true
			ORDER BY LastModifiedDate ASC];

		// Step1: Disable all Appointments
		Map<String, C501_Appointment__c> allAppointmentsByName = new Map<String, C501_Appointment__c>();
		Map<Id, C501_Appointment__c> updateAppointments = new Map<Id, C501_Appointment__c>();
		for ( C501_Appointment__c appointment:allAppointments) {
			try {
				appointment.Enable_Previous__c = appointment.Enable__c;
				appointment.Enable__c = false;
				updateAppointments.put(appointment.Id, appointment);

				// Build ByName map for processing later
				allAppointmentsByName.put(appointment.Name, appointment);
			}
			catch (Exception e) {
				appointmentScheduleList[0].AddError('updateAppointmentSchedule::Exception - ' + String.valueOf(e));
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
		for ( C501_Appointment_Schedule__c appointmentSchedule :allAppointmentSchedules ) {

			if (!appointmentSchedule.Enable__c) {
				continue;
			}

			try {
				DateTime appointmentDateTime = appointmentSchedule.Scheduled_Start_Date_Time__c;

				Set<DateTime> appointmentDays = new Set<DateTime>();
				appointmentDays.add(appointmentDateTime);

				while (appointmentSchedule.Range_Of_Recurrence_End_By__c != null &&
					appointmentDateTime.date() <= appointmentSchedule.Range_Of_Recurrence_End_By__c) {
					
					// Set appointmentDateTime to first day of the month
					appointmentDateTime = appointmentDateTime.addDays(-1 * (appointmentDateTime.day() - 1));

					for ( Integer weekday = 0; weekday <= 6; weekday++ ) {

						if (appointmentDateTime < appointmentSchedule.Scheduled_Start_Date_Time__c) {
							appointmentDateTime = appointmentDateTime.addDays(1);
							continue;
						}

						String dayOfWeek = appointmentDateTime.format('E');
						System.debug('**********dayOfWeek: ' + dayOfWeek + ' appointmentSchedule.Days_of_Week__c: ' + appointmentSchedule.Days_of_Week__c);

						if (appointmentSchedule.Days_of_Week__c.contains(dayOfWeek)) {
							for ( String weeklyOccurence :appointmentSchedule.Weekly_Occurrence__c.split(';')) {

								Integer weeklyOccuranceFactor = Integer.valueOf(weeklyOccurence.left(1)) - 1;
								DateTime appointmentDayAdd = appointmentDateTime.addDays(7 * weeklyOccuranceFactor);

								if (appointmentDayAdd.month() ==  appointmentDateTime.month()) {
									appointmentDays.add(appointmentDayAdd);
								}						
							}
						}

						appointmentDateTime = appointmentDateTime.addDays(1);
					}

					// Set appointmentDateTime to next month
					appointmentDateTime = appointmentDateTime.addMonths(1);
				}

				Integer endTimeInMinutes = appointmentSchedule.Scheduled_End_Time__c.hour() * 60 + appointmentSchedule.Scheduled_End_Time__c.minute();
				Time appointmentTime = appointmentDateTime.time();
				Integer appointmentTimeInMinutes = appointmentTime.hour() * 60 + appointmentTime.minute();
				Integer numberTimeIntervals = (endTimeInMinutes - appointmentTimeInMinutes) / 15;
				if (numberTimeIntervals > 96) {
					// Throw Exception/Error
					continue;
				}

				for (DateTime appointment :appointmentDays) {

					// Skip processing times that are in the past
					if (appointment.date() < dateToday) {
						continue;
					}

					Integer numberIntervals = numberTimeIntervals;
					appointmentDateTime = appointment;

					// Salesforce Apex DateTime Rounding Error - make sure starting on same start hour
					appointmentDateTime = appointmentDateTime.addHours(appointmentSchedule.Scheduled_Start_Date_Time__c.hour() - appointmentDateTime.hour());

					while (numberIntervals-- > 0) {
						String appointmentName = appointmentDateTime.format('yyyy-MM-dd - hh:mm a');
						String appointmentTimeDisplay = appointmentDateTime.format('hh:mm a');

						System.debug('**********Interval: ' + String.valueOf(numberIntervals) + ' appointmentTimeDisplay: ' + appointmentTimeDisplay + ' Name: ' + appointmentName);

						if (allAppointmentsByName.containsKey(appointmentName)) {
							C501_Appointment__c appointmentUpdate = allAppointmentsByName.get(appointmentName);

							appointmentUpdate.Appointment_Schedule__c = appointmentSchedule.Id;
							appointmentUpdate.Available_Time__c = appointmentDateTime;
							appointmentUpdate.Date__c = appointmentDateTime.date();
							appointmentUpdate.Time__c = appointmentTimeDisplay;

							appointmentUpdate.Enable__c = appointmentUpdate.Enable_Previous__c;
							appointmentUpdate.Maximum_Scheduled_Appointments__c = appointmentSchedule.Number_Appointments_per_15_min_interval__c;
							appointmentUpdate.Senior_Only_Appointments_60_and_over__c = appointmentSchedule.Senior_Only_Appointments_60_and_over__c;

							updateAppointments.put(appointmentUpdate.Id, appointmentUpdate);
						}
						else {
							C501_Appointment__c appointmentScheduling = new C501_Appointment__c(
								Name = appointmentName,
								Name_Unique__c = appointmentName,
								Appointment_Schedule__c = appointmentSchedule.Id,
								Available_Time__c = appointmentDateTime,
								Date__c = appointmentDateTime.date(),
								Time__c = appointmentTimeDisplay,
								Enable__c = true,
								Maximum_Scheduled_Appointments__c = appointmentSchedule.Number_Appointments_per_15_min_interval__c,
								Senior_Only_Appointments_60_and_over__c = appointmentSchedule.Senior_Only_Appointments_60_and_over__c);

							insertAppointments.put(appointmentName, appointmentScheduling);
						}

						// Increment by 15 minutes
						appointmentDateTime = appointmentDateTime.addMinutes(15);
					}
				}
			}
			catch (Exception e) {
				appointmentScheduleList[0].AddError('updateAppointmentSchedule::Exception - ' + String.valueOf(e));
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