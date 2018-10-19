trigger AppointmentScheduleTrigger on C501_Appointment_Schedule__c (after insert, after update, before delete) {

    C501_AppointmentScheduleTriggerHelper.get().updateAppointmentSchedule( Trigger.New, Trigger.oldMap);
}