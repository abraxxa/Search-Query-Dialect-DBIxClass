package Search::Query::Dialect::DBIxClass;

# ABSTRACT: Search::Query dialect for simple DBIx::Class query generation
use strict;
use warnings;
use base qw( Search::Query::Dialect::Native );

my %negated_prefix = (
    '+' => '-',
    '-' => '+',
);

my %negated_op = (
    ':'  => '!~',
    '~'  => '!~',
    '='  => '!=',
    '==' => '!=',
    '>'  => '<=',
    '<'  => '>=',
    '#'  => '!#',
    '()' => '()',
);

# add the negated negations
# we don't care if a hash key gets overwritten because they are just different
# chars for the same op
%negated_op = ( %negated_op, reverse %negated_op );

=head1 SYNOPSIS

    use Test::DBIx::Class::Example::Schema;
    use Search::Query;

    my $schema = Test::DBIx::Class::Example::Schema->connect();
    my $query = Search::Query->parser(
            dialect => 'DBIxClass',
            default_field => [qw( name description )],
        )->parse('foo bar -baz');
    my $rs = $schema->resultset('Foo')->search($query->as_dbic_query);

=head1 DESCRIPTION

    Search::Query::Dialect::DBIxClass extends L<Search::Query::Dialect::Native>
    by an as_dbic_query method that returns a hashref that can be passed to
    L<DBIx::Class::ResultSet/search>.

=head1 METHODS

=head2 init
 
Overrides base method and sets DBIx::Class-appropriate defaults.
It adds '!#' to the op_regex which is the 'not in list of values' operator.

=cut

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    my $op_regex = $self->parser->{op_regex};
    $self->parser->{op_regex} = qr/$op_regex|!#/;

    return $self;
}

sub _wrap_dbic_ops {
    return scalar @_ == 1
        ? $_[0]
        : [@_];
}

sub _dbic_op {
    my ( $self, $clause, $prefix, $colnames ) = @_;
    die 'no clause'
        unless defined $clause;
    die 'no prefix'
        unless defined $prefix;
    die 'column names required'
        unless defined $colnames;

    # normalize operator
    my $op = $clause->{op} || ":";

    # the - prefix inverts the ops
    if ( $prefix eq '-' ) {
        $op =
            exists $negated_op{$op}
            ? $negated_op{$op}
            : die "negated op for '$op' not handled by DBIxClass dialect";
    }

    if ( $op eq '()' ) {
        return $self->as_dbic_query( $clause->{value}, $prefix );
    }
    elsif ( $op eq ':' || $op eq '~' ) {
        return _wrap_dbic_ops(
            map {
                \[  "LOWER($_) LIKE ?",
                    [ plain_value => "%$clause->{value}%" ]
                    ]
            } @$colnames
        );
    }
    elsif ( $op eq '!~' ) {
        return _wrap_dbic_ops(
            map {
                \[  "COALESCE( LOWER($_), '' ) NOT LIKE ?",
                    [ plain_value => "%$clause->{value}%" ]
                    ]
            } @$colnames
        );
    }
    elsif ( $op eq '=' || $op eq '==' ) {
        return _wrap_dbic_ops(
            map {
                { $_ => $clause->{value} }
            } @$colnames
        );
    }
    elsif ( $op eq '>' || $op eq '<' || $op eq '>=' || $op eq '<=' ) {
        return _wrap_dbic_ops(
            map {
                { $_ => { $op => $clause->{value} } }
            } @$colnames
        );
    }
    elsif ( $op eq '#' ) {
        return _wrap_dbic_ops(
            map {
                { $_ => { -in => [ split( /,/, $clause->{value} ) ] } }
            } @$colnames
        );
    }
    elsif ( $op eq '!#' ) {
        return _wrap_dbic_ops(
            map {
                { $_ => { -not_in => [ split( /,/, $clause->{value} ) ] } }
            } @$colnames
        );
    }
    else {
        die "operator '$op' not supported by DBIxClass dialect";
    }
}

=head2 as_dbic_query

    Returns the query as hashref that can be passed to
    L<DBIx::Class::ResultSet/search>.

=cut

sub as_dbic_query {
    my $self         = shift;
    my $tree         = shift || $self;    # if called recursively by the () op
    my $query_prefix = shift || '+';

    # ensure default_field is always an arrayref
    my @default_fields =
        ( exists $self->parser->{default_field}
            && !ref $self->parser->{default_field} )
        ? [ $self->parser->{default_field} ]
        : @{ $self->parser->{default_field} };

    my @q;
    foreach my $prefix ( '+', '-' ) {
        next unless exists $tree->{$prefix};

        for my $clause ( @{ $tree->{$prefix} } ) {
            my @colnames =
                defined $clause->{field}
                ? ( $clause->{field} )
                : @default_fields;

            my $clause_prefix =
                  $query_prefix eq '-'
                ? $negated_prefix{$prefix}
                : $prefix;

            my $dbic_op =
                $self->_dbic_op( $clause, $clause_prefix, \@colnames );

            push @q, $dbic_op;
        }
    }

    my %search_params = ( -and => \@q );

    return \%search_params;
}

1;
