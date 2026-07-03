// Creates Setup Text (Parameter) records from the managed package QuoteSettingsDefaults JSON.
// Run before post-setup-entities.apex to avoid mixed DML with setup objects (Group, GroupMember).

System.debug('Appero Quote partner setup: quote parameters started');

Map<String, String> demoParameterOverrides = new Map<String, String>{
    'addAddOnsRespectingProductGroups' => 'true',
    'defaultQuoteEmailTemplate' => 'Send_Quote_Template_EN',
    'defaultOrderConfirmationEmailTemplate' => 'Send_OrderConfirmation_Email_EN'
};

List<StaticResource> quoteSettingsDefaultsResources = [
    SELECT Body
    FROM StaticResource
    WHERE Name = 'QuoteSettingsDefaults'
    LIMIT 1
];

System.Assert.isFalse(
    quoteSettingsDefaultsResources.isEmpty(),
    'Missing managed static resource QuoteSettingsDefaults. Install the Appero Quote package first.'
);

Map<String, Object> settingsByTitle = (Map<String, Object>) JSON.deserializeUntyped(
    quoteSettingsDefaultsResources[0].Body.toString()
);

Map<String, sf42_quotefx__SF42_QuoteSetup__c> existingByTitle = new Map<String, sf42_quotefx__SF42_QuoteSetup__c>();
for (sf42_quotefx__SF42_QuoteSetup__c existingRecord : [
    SELECT Id, sf42_quotefx__SF42_QuoSetup_Title__c
    FROM sf42_quotefx__SF42_QuoteSetup__c
    WHERE sf42_quotefx__SF42_QuoSetup_Typ__c = 'Parameter'
]) {
    existingByTitle.put(existingRecord.sf42_quotefx__SF42_QuoSetup_Title__c, existingRecord);
}

List<sf42_quotefx__SF42_QuoteSetup__c> recordsToInsert = new List<sf42_quotefx__SF42_QuoteSetup__c>();
List<sf42_quotefx__SF42_QuoteSetup__c> recordsToUpdate = new List<sf42_quotefx__SF42_QuoteSetup__c>();

for (String title : settingsByTitle.keySet()) {
    Map<String, Object> settingDetail = (Map<String, Object>) settingsByTitle.get(title);
    String value = demoParameterOverrides.containsKey(title)
        ? demoParameterOverrides.get(title)
        : String.valueOf(settingDetail.get('default_newInstallation'));
    String englishDescription = String.valueOf(settingDetail.get('description'));
    String germanDescription = String.valueOf(settingDetail.get('description_de'));

    sf42_quotefx__SF42_QuoteSetup__c setupTextRecord = existingByTitle.get(title);
    if (setupTextRecord == null) {
        setupTextRecord = new sf42_quotefx__SF42_QuoteSetup__c();
        setupTextRecord.sf42_quotefx__SF42_QuoSetup_Title__c = title;
        recordsToInsert.add(setupTextRecord);
    } else {
        recordsToUpdate.add(setupTextRecord);
    }

    setupTextRecord.sf42_quotefx__SF42_QuoSetup_Longtext__c = value;
    setupTextRecord.sf42_quotefx__SF42_QuoSetup_Typ__c = 'Parameter';
    setupTextRecord.sf42_quotefx__SF42_Description__c = englishDescription;
    setupTextRecord.sf42_quotefx__SF42_Description2__c = germanDescription;
    setupTextRecord.sf42_quotefx__SF42_Isactive__c = true;
}

if (!recordsToInsert.isEmpty()) {
    insert recordsToInsert;
}
if (!recordsToUpdate.isEmpty()) {
    update recordsToUpdate;
}

System.debug('Appero Quote partner setup: quote parameters completed');
