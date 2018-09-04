<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>Event_Notification_Alert</fullName>
        <description>Event Notification Alert</description>
        <protected>false</protected>

        <!-- White Center Foodbank Production -->
<!--        
        <recipients>
            <field>C501_Contact__c</field>
            <type>contactLookup</type>
        </recipients>
        <senderAddress>cheo@whitecenterfoodbank.org</senderAddress>
        <senderType>OrgWideEmailAddress</senderType>
-->
        <!-- 501Commons Foodbank Sandbox -->
        <recipients>
            <recipient>daveb@501commons.org.foodbank</recipient>
            <type>user</type>
        </recipients>
        <senderType>CurrentUser</senderType>

        <template>Salesforce_Event_Scheduler/Event_Notification_Template</template>
    </alerts>
</Workflow>
