// Creates setup entities (public group membership) in a separate transaction
// to avoid mixed DML with custom object updates in post-setup-custom-objects.apex.

System.debug('Appero Quote partner setup: setup entities started');

Group quoteAdminGroup = new Group(
    Name = 'QuoteAdmin',
    Type = 'Regular'
);
insert quoteAdminGroup;

Id runningUserId = UserInfo.getUserId();
insert new GroupMember(
    GroupId = quoteAdminGroup.Id,
    UserOrGroupId = runningUserId
);

System.debug('Appero Quote partner setup: setup entities completed');
