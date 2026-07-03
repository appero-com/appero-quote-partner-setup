// Resolves demo data placeholders on package custom objects and related records.
// Run before post-setup-entities.apex to avoid mixed DML with setup objects (Group, GroupMember).

System.debug('Appero Quote partner setup: custom objects started');

Map<String, String> placeholderProductGroupToName = new Map<String, String>{
    'placeholderProductGroup1' => 'Support',
    'placeholderProductGroup2' => 'Licenses',
    'placeholderProductGroup3' => 'One-time Service',
    'placeholderProductGroup4' => 'Training',
    'placeholderProductGroup5' => 'Installation',
    'placeholderProductGroup6' => 'Technical Support',
    'placeholderProductGroup7' => 'Hardware',
    'placeholderProductGroup8' => 'Recurring',
    'placeholderProductGroup9' => 'OneTime'
};

String placeholderFirstPage = 'Placeholder1stPage';
String placeholderSecondPage = 'Placeholder2ndPage';
String firstPageName = 'apperoLetterheadFirstPage';
String secondPageName = 'apperoLetterheadSecondPage';

List<sf42_quotefx__SF42_QuoteStyle__c> styles = [
    SELECT Id,
           sf42_quotefx__SF42_FirstPageDocumentID__c,
           sf42_quotefx__SF42_SecondPageDocumentId__c
    FROM sf42_quotefx__SF42_QuoteStyle__c
    WITH USER_MODE
];

List<StaticResource> firstPageResources = [
    SELECT Id, Body
    FROM StaticResource
    WHERE Name = 'apperoLetterHeadCover'
    LIMIT 1
];
List<StaticResource> secondPageResources = [
    SELECT Id, Body
    FROM StaticResource
    WHERE Name = 'apperoBackground'
    LIMIT 1
];

System.Assert.isFalse(
    firstPageResources.isEmpty() || secondPageResources.isEmpty(),
    'Missing static resources apperoLetterHeadCover and/or apperoBackground. Deploy metadata/staticresources first.'
);

List<Document> docs = new List<Document>{
    new Document(
        FolderId = UserInfo.getUserId(),
        Body = firstPageResources[0].Body,
        Name = firstPageName
    ),
    new Document(
        FolderId = UserInfo.getUserId(),
        Body = secondPageResources[0].Body,
        Name = secondPageName
    )
};
insert docs;

List<sf42_quotefx__SF42_QuoteStyle__c> stylesToUpdate = new List<sf42_quotefx__SF42_QuoteStyle__c>();
for (sf42_quotefx__SF42_QuoteStyle__c style : styles) {
    if (
        style.sf42_quotefx__SF42_FirstPageDocumentID__c == placeholderFirstPage
        || style.sf42_quotefx__SF42_SecondPageDocumentId__c == placeholderSecondPage
    ) {
        style.sf42_quotefx__SF42_FirstPageDocumentID__c = String.valueOf(docs[0].Id);
        style.sf42_quotefx__SF42_SecondPageDocumentId__c = String.valueOf(docs[1].Id);
        stylesToUpdate.add(style);
    }
}
update stylesToUpdate;

Map<String, Id> productGroupNameToId = new Map<String, Id>();
for (sf42_quotefx__SF42_ProductGroup__c productGroup : [
    SELECT Id, Name
    FROM sf42_quotefx__SF42_ProductGroup__c
    WITH USER_MODE
]) {
    productGroupNameToId.put(productGroup.Name, productGroup.Id);
}

List<sf42_quotefx__SF42_GenLineItem__c> changedPositions = new List<sf42_quotefx__SF42_GenLineItem__c>();
for (sf42_quotefx__SF42_GenLineItem__c position : [
    SELECT Id, sf42_quotefx__SF42_QuoLI_GroupID__c
    FROM sf42_quotefx__SF42_GenLineItem__c
    WITH USER_MODE
]) {
    String groupIdValue = position.sf42_quotefx__SF42_QuoLI_GroupID__c;
    if (groupIdValue == null || groupIdValue == '-') {
        continue;
    }
    if (!placeholderProductGroupToName.containsKey(groupIdValue)) {
        continue;
    }

    String groupName = placeholderProductGroupToName.get(groupIdValue);
    if (productGroupNameToId.containsKey(groupName)) {
        position.sf42_quotefx__SF42_QuoLI_GroupID__c = productGroupNameToId.get(groupName);
        changedPositions.add(position);
    }
}
update changedPositions;

String quoteNumberPrefix = 'Quote-';
Decimal quoteNumberCount = 1;
List<sf42_quotefx__SF42_Number__c> existingQuoteNumbers = [
    SELECT Id
    FROM sf42_quotefx__SF42_Number__c
    WHERE sf42_quotefx__SF42_Type__c = 'Quote'
    LIMIT 1
];
if (existingQuoteNumbers.isEmpty()) {
    insert new sf42_quotefx__SF42_Number__c(
        sf42_quotefx__SF42_Numbertext__c = quoteNumberPrefix,
        sf42_quotefx__SF42_Count__c = quoteNumberCount,
        sf42_quotefx__SF42_Type__c = 'Quote'
    );
}

System.debug('Appero Quote partner setup: custom objects completed');
