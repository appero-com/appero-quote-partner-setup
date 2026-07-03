// Deletes all records for objects loaded by data/import-plan.json.
// For dedicated test orgs only. Does not touch permsets, groups, or documents.
//
// Uses Database.delete(records, false) so one bad row (e.g. standard PricebookEntry)
// does not abort the entire reset.
//
// Usage:
//   sf apex run --file scripts/apex/reset-import-data.apex --target-org <alias>
//   sf data import tree --plan data/import-plan.json --target-org <alias>
//   sf apex run --file scripts/apex/create-pricebook-entries.apex --target-org <alias>

System.debug('Appero Quote: reset import data started');

List<String> deleteSteps = new List<String>{
    'SELECT Id FROM sf42_quotefx__SF42_GenLineItem__c',
    'SELECT Id FROM sf42_quotefx__SF42_Discount_Matrix__c',
    'SELECT Id FROM Opportunity',
    'SELECT Id FROM sf42_quotefx__SF42_Quote__c',
    'SELECT Id FROM sf42_quotefx__SF42_ProductEntry__c',
    'SELECT Id FROM PricebookEntry WHERE Pricebook2.IsStandard = false',
    'SELECT Id FROM PricebookEntry WHERE Pricebook2.IsStandard = true',
    'SELECT Id FROM sf42_quotefx__SF42_QuoProductProperty__c',
    'SELECT Id FROM Product2',
    'SELECT Id FROM Contact',
    'SELECT Id FROM Account',
    'SELECT Id FROM Pricebook2 WHERE IsStandard = false',
    'SELECT Id FROM sf42_quotefx__SF42_ProductGroup__c',
    'SELECT Id FROM sf42_quotefx__SF42_QuoteStyle__c',
    'SELECT Id FROM sf42_quotefx__SF42_Account_Group__c',
    'SELECT Id FROM sf42_quotefx__SF42_Discount_Type__c'
};

for (String soql : deleteSteps) {
    List<SObject> records = Database.query(soql);
    if (records.isEmpty()) {
        continue;
    }

    Database.delete(records, false);
}

System.debug('Appero Quote: reset import data completed');
