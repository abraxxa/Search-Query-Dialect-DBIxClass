#!/usr/bin/env perl

use strict;
use feature ":5.10";
use Data::Dumper::Concise;
use Search::Query;

say '--> Dialect::Native';
say (
    Search::Query->parser(
        default_field => [qw( name email )],
        fields        => [qw( name email )],
    )->parse('o')
);

say '--> Dialect::SQL';
say (
    Search::Query->parser(
        dialect       => 'SQL',
        default_field => [qw( name email )],
        fields        => [qw( name email )],
    )->parse('o')
);

say '--> Dialect::DBIxClass';
say Dumper(
    Search::Query->parser(
        dialect       => 'DBIxClass',
        default_field => [qw( name email )],
        fields        => [qw( name email )],
    )->parse('o')->as_dbic_query
);
