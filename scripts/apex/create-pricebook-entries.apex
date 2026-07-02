// Creates standard and custom PricebookEntry rows for demo products.
// The org standard price book cannot be referenced via sf data import tree JSON.
// Custom demo price book is imported as "appero Pricebook" (5-Pricebook2.json).
// Run after sf data import tree completes.

String customPricebookName = 'appero Pricebook';

System.debug('Appero Quote: creating pricebook entries');

Map<String, Decimal> productNameToUnitPrice = new Map<String, Decimal>{
    'appero quote Implementation \'Premium\'' => 9990,
    'appero quote Support \'Business\'' => 0,
    'appero quote License' => 42,
    'appero quote Starter Bundle' => 0,
    'Approval Process Implementation' => 990,
    'appero quote Admin Training' => 3450,
    'Discount Product' => 0
};

Id standardPricebookId = [
    SELECT Id
    FROM Pricebook2
    WHERE IsStandard = true
    LIMIT 1
].Id;

Id apperoPricebookId = [
    SELECT Id
    FROM Pricebook2
    WHERE Name = :customPricebookName AND IsStandard = false
    LIMIT 1
].Id;

Map<Id, Product2> productsById = new Map<Id, Product2>([
    SELECT Id, Name
    FROM Product2
    WHERE Name IN :productNameToUnitPrice.keySet()
]);

Set<String> existingKeys = new Set<String>();
for (PricebookEntry existing : [
    SELECT Product2Id, Pricebook2Id
    FROM PricebookEntry
    WHERE Pricebook2Id IN :new Set<Id>{ standardPricebookId, apperoPricebookId }
      AND Product2Id IN :productsById.keySet()
]) {
    existingKeys.add(existing.Product2Id + ':' + existing.Pricebook2Id);
}

List<PricebookEntry> entries = new List<PricebookEntry>();
for (Product2 product : productsById.values()) {
    Decimal unitPrice = productNameToUnitPrice.get(product.Name);
    for (Id pricebookId : new List<Id>{ standardPricebookId, customPricebookId }) {
        String key = product.Id + ':' + pricebookId;
        if (!existingKeys.contains(key)) {
            entries.add(new PricebookEntry(
                Pricebook2Id = pricebookId,
                Product2Id = product.Id,
                UnitPrice = unitPrice,
                IsActive = true,
                UseStandardPrice = false
            ));
        }
    }
}

if (!entries.isEmpty()) {
    insert entries;
}

System.debug('Appero Quote: created ' + entries.size() + ' pricebook entries');
