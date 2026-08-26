DateTime startTime = System.now();
DateTime endTime = startTime.addHours(2);
TraceFlag tf = new TraceFlag(
    TracedEntityId = '005fj00000LqSlhAAF',
    LogType = 'USER_DEBUG',
    StartDate = startTime,
    ExpirationDate = endTime,
    DebugLevelId = [SELECT Id FROM DebugLevel LIMIT 1].Id
);
insert tf;
System.debug('Trace flag created: ' + tf.Id);
