BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}  

use strict;
use warnings;

use Test::More;
use Log::Log4perl::MDC;

Log::Log4perl::MDC::put('test-one', 'value-one');
is( Log::Log4perl::MDC::get('test-one'), 
    'value-one', 
    'Calling put/get class methods works with colon notation'
);

Log::Log4perl::MDC->put('test-two', 'value-two');
is( Log::Log4perl::MDC->get('test-two'),
    'value-two',
    'Calling put/get class methods works with arrow notation'
);

# We have verified both arrow and colon notation work. Sticking
# with arrow notation from now on.

Log::Log4perl::MDC->put('test-three'          => 'value-three', 
			'test-three-part-two' => 'value-three-part-two');
is( Log::Log4perl::MDC->get('test-three') . Log::Log4perl::MDC->get('test-three-part-two'),
    'value-threevalue-three-part-two',
    'Calling put with multiple key/value pairs adds all to store'
);

Log::Log4perl::MDC->put({ 'test-four' => 'value-four',
			  'test-four-part-two' => 'value-four-part-two' });
is( Log::Log4perl::MDC->get('test-four') . Log::Log4perl::MDC->get('test-four-part-two'),
    'value-fourvalue-four-part-two',
    'Calling put with hashref adds all key/values to store'
);

is( Log::Log4perl::MDC->get('test-five'), undef, 'Calling get on unknown key returns undef');

Log::Log4perl::MDC->delete('test-three');
is( Log::Log4perl::MDC->get('test-three'),
    undef,
    'Calling delete on a key removes from context'
);

Log::Log4perl::MDC->remove();
is_deeply(Log::Log4perl::MDC->get_context(), {}, 'Calling remove deletes all entries');

done_testing;
