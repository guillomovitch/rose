package Rose::DB::Object::Metadata::Column::Array;

use strict;

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.788';

__PACKAGE__->add_common_method_maker_argument_names
(
  qw(default dimensions)
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->common_method_maker_argument_names ]
);

sub type { 'array' }

foreach my $type (__PACKAGE__->available_method_types)
{
  __PACKAGE__->method_maker_type($type => 'array')
}

sub should_inline_value
{
  my($self, $db, $value) = @_;
  no warnings 'uninitialized';
  return (($db->validate_array_keyword($value) && $db->should_inline_array_keyword($value)) ||
          ($db->keyword_function_calls && $value =~ /^\w+\(.*\)$/)) ? 1 : 0;
}

sub parse_value  { shift; shift->parse_array(@_)  }
sub format_value { shift; shift->format_array(@_) }

sub method_uses_formatted_key
{
  my($self, $type) = @_;
  return 1  if($type eq 'get' || $type eq 'set' || $type eq 'get_set');
  return 0;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Array - Array column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Array;

  $col = Rose::DB::Object::Metadata::Column::Array->new(...);
  $col->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for array columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<array|Rose::DB::Object::MakeMethods::Generic/array>, ...

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<array|Rose::DB::Object::MakeMethods::Generic/array>, ...

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<array|Rose::DB::Object::MakeMethods::Generic/array>, ...

=back

See the L<Rose::DB::Object::Metadata::Column|Rose::DB::Object::Metadata::Column/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 OBJECT METHODS

=over 4

=item B<dimensions [ARRAYREF]>

Get or set the dimensions of the column as a reference to an array of integer dimensions.

=item B<parse_value DB, VALUE>

Parse VALUE and return a reference to an array containing the array values.  DB is a L<Rose::DB> object that is  used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "array".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@gmail.com)

=head1 LICENSE

Copyright (c) 2010 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
