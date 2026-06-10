/**
 * Post-import setup for Appero Quote partner demo orgs.
 *
 * Replace the placeholder resolution logic below with your production Apex
 * once demo data field API names and placeholder tokens are finalized.
 */
System.debug('Appero Quote partner setup: post-import started');

// --- Placeholder resolution (customize) ------------------------------------
// Map tokens from imported CSV text fields to real Salesforce record Ids.
// Example:
// Map<String, String> placeholders = new Map<String, String>{
//     'PLACEHOLDER_ACCOUNT_MAIN' => [SELECT Id FROM Account WHERE Name = 'Demo Account' LIMIT 1].Id
// };
// for (Your_Settings__c setting : [SELECT Id, Related_Record_Id__c FROM Your_Settings__c WHERE Related_Record_Id__c LIKE 'PLACEHOLDER_%']) {
//     setting.Related_Record_Id__c = placeholders.get(setting.Related_Record_Id__c);
// }
// update settings;

// --- Initial settings (customize) ------------------------------------------
// Create or update package custom settings / configuration records here.

// --- Verification ----------------------------------------------------------
String namespacePrefix = 'appero_quote';
Integer installedComponents = [
    SELECT COUNT()
    FROM InstalledSubscriberPackage
    WHERE SubscriberPackage.NamespacePrefix = :namespacePrefix
];
System.assert(installedComponents > 0, 'Appero Quote package does not appear to be installed.');

System.debug('Appero Quote partner setup: post-import completed successfully');
