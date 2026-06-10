// Creates setup entities (public group membership) in a separate transaction
// to avoid mixed DML with custom object updates in post-setup-custom-objects.apex.

System.debug('Appero Quote partner setup: setup entities started');

List<Group> existingGroups = [
    SELECT Id
    FROM Group
    WHERE Name = 'QuoteAdmin' AND Type = 'Regular'
    LIMIT 1
];

Group quoteAdminGroup;
if (existingGroups.isEmpty()) {
    quoteAdminGroup = new Group(
        Name = 'QuoteAdmin',
        Type = 'Regular'
    );
    insert quoteAdminGroup;
} else {
    quoteAdminGroup = existingGroups[0];
}

Id runningUserId = UserInfo.getUserId();
List<GroupMember> existingMembers = [
    SELECT Id
    FROM GroupMember
    WHERE GroupId = :quoteAdminGroup.Id
      AND UserOrGroupId = :runningUserId
    LIMIT 1
];

if (existingMembers.isEmpty()) {
    insert new GroupMember(
        GroupId = quoteAdminGroup.Id,
        UserOrGroupId = runningUserId
    );
}

System.debug('Appero Quote partner setup: setup entities completed');
