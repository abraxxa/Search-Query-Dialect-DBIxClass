use strict;
use warnings;
use Test::More;
use Test::DBIx::Class qw(:resultsets);
use Search::Query;

use Data::Dumper::Concise;

fixtures_ok 'core' => 'installed the core fixtures from configuration files';

my @cases = ( [], [qw(name email)] );
for (@cases) {
    ok( my $parser = Search::Query->parser(
            dialect        => 'DBIxClass',
            default_field  => [qw( name email )],
            ( @$_ ? ( fields => $_ ) : () ),
            croak_on_error => 1,
        ),
        'Search::Query::Parser constructed ok'
    );

    {
        my $rs_query    = Person->search_rs( $parser->parse('n')->as_dbic_query );
        my $rs_expected = Person->search_rs(
            [   \[ "LOWER(name) LIKE ?",  [ plain_value => "%n%" ] ],
                \[ "LOWER(email) LIKE ?", [ plain_value => "%n%" ] ],
            ]
        );
        eq_resultset( $rs_query, $rs_expected,
            'one term, default fields, included' );
    }
}

done_testing;
