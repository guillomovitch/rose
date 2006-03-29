#!/usr/bin/perl -w

use strict;

use Test::More tests => 381;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Util');
}

Rose::DB::Object::Util->import(':all');

our($PG_HAS_CHKPASS, $HAVE_PG, $HAVE_MYSQL, $HAVE_INFORMIX, $HAVE_SQLITE);

#
# Postgres
#

SKIP: foreach my $db_type (qw(pg pg_with_schema))
{
  skip("Postgres tests", 150)  unless($HAVE_PG);

  Rose::DB->default_type($db_type);

  TEST_HACK:
  {
    no warnings;
    *MyPgObject::init_db = sub { Rose::DB->new($db_type) };
  }

  my $o = MyPgObject->new(name => 'John', 
                          k1   => 1,
                          k2   => undef,
                          k3   => 3);

  ok(ref $o && $o->isa('MyPgObject'), "new() 1 - $db_type");

  $o->flag2('TRUE');
  $o->date_created('now');
  $o->last_modified($o->date_created);
  $o->save_col(7);

  if(rand >= 0.5)
  {
    ok($o->save, "save() 1 - $db_type");
  }
  else
  {
    ok($o->insert, "insert() 1 - $db_type");
  }

  is($o->meta->primary_key->sequence_names->[0], 'rose_db_object_test_id_seq', 
     "pk sequence name - $db_type");

  ok(is_in_db($o), "is_in_db - $db_type");

  is($o->id, 1, "auto-generated primary key - $db_type");

  ok($o->load, "load() 1 - $db_type");

  $o->name('C' x 50);
  is($o->name, 'C' x 32, "varchar truncation - $db_type");

  $o->name('John');

  $o->code('A');
  is($o->code, 'A     ', "character padding - $db_type");

  $o->code('C' x 50);
  is($o->code, 'C' x 6, "character truncation - $db_type");

  my $ouk;
  ok($ouk = MyPgObject->new(k1 => 1,
                            k2 => undef,
                            k3 => 3)->load, "load() uk 1 - $db_type");

  ok(!$ouk->not_found, "not_found() uk 1 - $db_type");

  is($ouk->id, 1, "load() uk 2 - $db_type");
  is($ouk->name, 'John', "load() uk 3 - $db_type");

  ok($ouk->save, "save() uk 1 - $db_type");

  my $o2 = MyPgObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MyPgObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 7, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  $o2->set_status('foo');
  is($o2->get_status, 'foo', 'get_status()');
  $o2->set_status('active');
  eval { $o2->set_status };
  ok($@, 'set_status()');

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  my $clone = $o2->clone;
  ok($o2->start eq $clone->start, "clone() 1 - $db_type");
  $clone->start->set(year => '1960');
  ok($o2->start ne $clone->start, "clone() 2 - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyPgObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyPgObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  ok($o->load, "load() 4 - $db_type");

  SKIP:
  {
    if($PG_HAS_CHKPASS)
    {
      $o->{'password_encrypted'} = ':8R1Kf2nOS0bRE';

      ok($o->password_is('xyzzy'), "chkpass() 1 - $db_type");
      is($o->password, 'xyzzy', "chkpass() 2 - $db_type");

      $o->password('foobar');

      ok($o->password_is('foobar'), "chkpass() 3 - $db_type");
      is($o->password, 'foobar', "chkpass() 4 - $db_type");

      ok($o->save, "save() 3 - $db_type");
    }
    else
    {
      skip("chkpass tests", 5);
    }
  }

  my $o5 = MyPgObject->new(id => $o->id);

  ok($o5->load, "load() 5 - $db_type");

  SKIP:
  {
    if($PG_HAS_CHKPASS)
    {
      ok($o5->password_is('foobar'), "chkpass() 5 - $db_type");
      is($o5->password, 'foobar', "chkpass() 6 - $db_type"); 
    }
    else
    {
      skip("chkpass tests", 2);
    }
  }

  $o5->nums([ 4, 5, 6 ]);
  ok($o5->save, "save() 4 - $db_type");
  ok($o->load, "load() 6 - $db_type");

  is($o5->nums->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o5->nums->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o5->nums->[2], 6, "load() verify 12 (array value) - $db_type");

  my @a = $o5->nums;

  is($a[0], 4, "load() verify 13 (array value) - $db_type");
  is($a[1], 5, "load() verify 14 (array value) - $db_type");
  is($a[2], 6, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  ok($o->delete, "delete() - $db_type");

  $o = MyPgObject->new(name => 'John', id => 9);
  $o->save_col(22);
  ok($o->save, "save() 4 - $db_type");
  $o->save_col(50);
  ok($o->save, "save() 5 - $db_type");

  $ouk = MyPgObject->new(save_col => 50);
  ok($ouk->load, "load() aliased unique key - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, "alias_column() nonesuch - $db_type");

  # This is okay now
  #eval { $o->meta->alias_column(id => 'foo') };
  #ok($@, "alias_column() primary key - $db_type");

  $o = MyPgObject->new(id => 777);

  $o->meta->error_mode('fatal');

  $o->dbh->{'PrintError'} = 0;

  eval { $o->load };
  ok($@ && $o->not_found, "load() not found fatal - $db_type");

  $o->id('abc');

  eval { $o->load };
  ok($@ && !$o->not_found, "load() fatal - $db_type");

  eval { $o->save };
  ok($@, "save() fatal - $db_type");

  $o = MyPgObject->new(id => 9999); # no such id

  $o->meta->error_mode('fatal');

  eval { $o->load() };
  ok($@, "load() non-speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 1 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");

  $o->meta->default_load_speculative(1);

  ok(!$o->load(), "load() speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 2 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");

  # Reset for next trip through loop
  $o->meta->default_load_speculative(0);
  $o->meta->error_mode('return');
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 83)  unless($HAVE_MYSQL);

  Rose::DB->default_type($db_type);

  my $o = MyMySQLObject->new(name => 'John',
                             k1   => 1,
                             k2   => undef,
                             k3   => 3);
$DB::single = 1;
  ok(ref $o && $o->isa('MyMySQLObject'), "new() 1 - $db_type");

  $o->flag2('true');
  $o->date_created('now');
  $o->last_modified($o->date_created);
  $o->save_col(22);

  $o->bitz3('11');

  if(rand >= 0.5)
  {
    ok($o->save, "save() 1 - $db_type");
  }
  else
  {
    ok($o->insert, "insert() 1 - $db_type");
  }

  ok($o->load, "load() 1 - $db_type");

  my $ox = MyMySQLObject->new(id => $o->id)->load;
  is($ox->bitz2->to_Bin(), '00', "spot check bitfield 1 - $db_type");
  is($ox->bitz3->to_Bin(), '0011', "spot check bitfield 2 - $db_type");

  eval { $o->name('C' x 50) };
  ok($@, "varchar overflow fatal - $db_type");

  $o->name('John');

  $o->code('A');
  is($o->code, 'A     ', "character padding - $db_type");

  eval { $o->code('C' x 50) };
  ok($@, "code overflow fatal - $db_type");
  $o->code('C' x 6);

  is($o->enums, 'foo', "enum 1 - $db_type");
  eval { $o->enums('blee') };
  ok($@, "enum 2 - $db_type");

  $o->enums('bar');

  my $ouk;

  ok($ouk = MyMySQLObject->new(k1 => 1,
                               k2 => undef,
                               k3 => 3)->load, "load() uk 1 - $db_type");

  ok(!$ouk->not_found, "not_found() uk 1 - $db_type");

  is($ouk->id, 1, "load() uk 2 - $db_type");
  is($ouk->name, 'John', "load() uk 3 - $db_type");

  ok($ouk->save, "save() uk 1 - $db_type");

  my $o2 = MyMySQLObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MyMySQLObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");
  is($o2->bitz2->to_Bin, '00', "bitz2() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");

  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 22, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  $o2->set_status('foo');
  is($o2->get_status, 'foo', 'get_status()');
  $o2->set_status('active');
  eval { $o2->set_status };
  ok($@, 'set_status()');

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");
  is($o2->bitz2->to_Bin, '00', "load() verify 10 (bitfield value) - $db_type");
  is($o2->bitz3->to_Bin, '0011', "load() verify 11 (bitfield value) - $db_type");

  my $clone = $o2->clone;
  ok($o2->start eq $clone->start, "clone() 1 - $db_type");
  $clone->start->set(year => '1960');
  ok($o2->start ne $clone->start, "clone() 2 - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyMySQLObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyMySQLObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  $o->nums([ 4, 5, 6 ]);
  ok($o->save, "save() 3 - $db_type");
  ok($o->load, "load() 4 - $db_type");

  is($o->nums->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o->nums->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o->nums->[2], 6, "load() verify 12 (array value) - $db_type");

  my @a = $o->nums;

  is($a[0], 4, "load() verify 13 (array value) - $db_type");
  is($a[1], 5, "load() verify 14 (array value) - $db_type");
  is($a[2], 6, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  ok($o->delete, "delete() - $db_type");

  $o = MyMySQLObject->new(name => 'John', id => 9);
  $o->save_col(22);

  ok($o->save, "save() 4 - $db_type");
  $o->save_col(50);
  ok($o->save, "save() 5 - $db_type");

  $ouk = MyMySQLObject->new(save_col => 50);
  ok($ouk->load, "load() aliased unique key - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, "alias_column() nonesuch - $db_type");

  # This is okay now
  #eval { $o->meta->alias_column(id => 'foo') };
  #ok($@, "alias_column() primary key - $db_type");

  $o = MyMySQLObject->new(id => 777);

  $o->meta->error_mode('fatal');

  $o->dbh->{'PrintError'} = 0;

  eval { $o->load };
  ok($@ && $o->not_found, "load() not found fatal - $db_type");

  my $old_table = $o->meta->table;

  $o->meta->table('nonesuch');

  eval { $o->load };
  ok($@ && !$o->not_found, "load() fatal - $db_type");

  eval { $o->save };
  ok($@, "save() fatal - $db_type");

  $o->meta->table($old_table);  
  $o->meta->error_mode('return');

  $o = MyMPKMySQLObject->new(name => 'John');

  ok($o->save, "save() 1 multi-value primary key with generated values - $db_type");

  is($o->k1, 1, "save() verify 1 multi-value primary key with generated values - $db_type");
  is($o->k2, 2, "save() verify 2 multi-value primary key with generated values - $db_type");

  $o = MyMPKMySQLObject->new(name => 'Alex');

  ok($o->save, "save() 2 multi-value primary key with generated values - $db_type");

  is($o->k1, 3, "save() verify 3 multi-value primary key with generated values - $db_type");
  is($o->k2, 4, "save() verify 4 multi-value primary key with generated values - $db_type");

  is($ox->bitz3->to_Bin(), '0011', "spot check bitfield 3 - $db_type");

  $ox->bitz3->Bit_On(3);
  is($ox->bitz3->to_Bin(), '1011', "spot check bitfield 4 - $db_type");

  $ox->save(insert => 1);

  $ox = MyMySQLObject->new(id => $ox->id)->load;
  is($ox->bitz3->to_Bin(), '1011', "spot check bitfield 5 - $db_type");

  $ox->bitz3->Bit_On(2);
  $ox->save;
  $ox = MyMySQLObject->new(id => $ox->id)->load;
  is($ox->bitz3->to_Bin(), '1111', "spot check bitfield 6 - $db_type");

  $o = MyMySQLObject->new(id => 9999); # no such id

  $o->meta->error_mode('fatal');

  eval { $o->load() };
  ok($@, "load() non-speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 1 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");

  $o->meta->default_load_speculative(1);

  ok(!$o->load(), "load() speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 2 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");
}

#
# Informix
#

SKIP: foreach my $db_type ('informix')
{
  skip("Informix tests", 73)  unless($HAVE_INFORMIX);

  Rose::DB->default_type($db_type);

  my $o = MyInformixObject->new(name => 'John', 
                                id   => 1,
                                k1   => 1,
                                k2   => undef,
                                k3   => 3);

  ok(ref $o && $o->isa('MyInformixObject'), "new() 1 - $db_type");

  $o->meta->allow_inline_column_values(1);

  $o->flag2('true');
  $o->date_created('current year to fraction(5)');
  $o->last_modified($o->date_created);
  $o->save_col(22);

  if(rand >= 0.5)
  {
    ok($o->save, "save() 1 - $db_type");
  }
  else
  {
    ok($o->insert, "insert() 1 - $db_type");
  }

  ok($o->load, "load() 1 - $db_type");

  $o->name('C' x 50);
  is($o->name, 'C' x 32, "varchar truncation - $db_type");

  $o->name('John');

  $o->code('A');
  is($o->code, 'A     ', "character padding - $db_type");

  $o->code('C' x 50);
  is($o->code, 'C' x 6, "character truncation - $db_type");

  my $ouk;
  ok($ouk = MyInformixObject->new(k1 => 1,
                                  k2 => undef,
                                  k3 => 3)->load, "load() uk 1 - $db_type");

  ok(!$ouk->not_found, "not_found() uk 1 - $db_type");

  is($ouk->id, 1, "load() uk 2 - $db_type");
  is($ouk->name, 'John', "load() uk 3 - $db_type");

  ok($ouk->save, "save() uk 1 - $db_type");

  my $o2 = MyInformixObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MyInformixObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 22, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  $o2->set_status('foo');
  is($o2->get_status, 'foo', 'get_status()');
  $o2->set_status('active');
  eval { $o2->set_status };
  ok($@, 'set_status()');

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  my $clone = $o2->clone;
  ok($o2->start eq $clone->start, "clone() 1 - $db_type");
  $clone->start->set(year => '1960');
  ok($o2->start ne $clone->start, "clone() 2 - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('current year to second');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyInformixObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyInformixObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  $o->nums([ 4, 5, 6 ]);
  $o->names([ qw(a b 3.1) ]);

  ok($o->save, "save() 3 - $db_type");
  ok($o->load, "load() 4 - $db_type");

  is($o->nums->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o->nums->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o->nums->[2], 6, "load() verify 12 (array value) - $db_type");

  $o->nums(7, 8, 9);

  my @a = $o->nums;

  is($a[0], 7, "load() verify 13 (array value) - $db_type");
  is($a[1], 8, "load() verify 14 (array value) - $db_type");
  is($a[2], 9, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  is($o->names->[0], 'a', "load() verify 10 (set value) - $db_type");
  is($o->names->[1], 'b', "load() verify 11 (set value) - $db_type");
  is($o->names->[2], '3.1', "load() verify 12 (set value) - $db_type");

  $o->names('c', 'd', '4.2');

  @a = $o->names;

  is($a[0], 'c', "load() verify 13 (set value) - $db_type");
  is($a[1], 'd', "load() verify 14 (set value) - $db_type");
  is($a[2], '4.2', "load() verify 15 (set value) - $db_type");
  is(@a, 3, "load() verify 16 (set value) - $db_type");

  ok($o->delete, "delete() - $db_type");

  $o = MyInformixObject->new(name => 'John', id => 9);

  $o->flag2('true');
  $o->date_created('current year to fraction(5)');
  $o->last_modified($o->date_created);
  $o->save_col(22);

  ok($o->save, "save() 4 - $db_type");
  $o->save_col(50);

  ok($o->save, "save() 5 - $db_type");

  $ouk = MyInformixObject->new(save_col => 50);
  ok($ouk->load, "load() aliased unique key - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, "alias_column() nonesuch - $db_type");

  # This is okay now
  #eval { $o->meta->alias_column(id => 'foo') };
  #ok($@, "alias_column() primary key - $db_type");

  $o = MyInformixObject->new(id => 777);

  $o->meta->error_mode('fatal');

  $o->dbh->{'PrintError'} = 0;

  eval { $o->load };
  ok($@ && $o->not_found, "load() not found fatal - $db_type");

  $o->id('abc');

  eval { $o->load };
  ok($@ && !$o->not_found, "load() fatal - $db_type");

  eval { $o->save };
  ok($@, "save() fatal - $db_type");

  #$o->meta->error_mode('return');

  $o = MyInformixObject->new(id => 9999); # no such id

  $o->meta->error_mode('fatal');

  eval { $o->load() };
  ok($@, "load() non-speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 1 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");

  $o->meta->default_load_speculative(1);

  ok(!$o->load(), "load() speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 2 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");
}

#
# SQLite
#

SKIP: foreach my $db_type ('sqlite')
{
  skip("SQLite tests", 73)  unless($HAVE_SQLITE);

  Rose::DB->default_type($db_type);

  my $o = MySQLiteObject->new(name => 'John',
                              k1   => 1,
                              k2   => undef,
                              k3   => 3);

  ok(ref $o && $o->isa('MySQLiteObject'), "new() 1 - $db_type");

  $o->flag2('true');
  $o->date_created('now');
  $o->last_modified($o->date_created);
  $o->save_col(22);

  if(rand >= 0.5)
  {
    ok($o->save, "save() 1 - $db_type");
  }
  else
  {
    ok($o->insert, "insert() 1 - $db_type");
  }

  ok($o->load, "load() 1 - $db_type");

  $o->name('C' x 50);
  is($o->name, 'C' x 32, "varchar truncation - $db_type");

  $o->name('John');

  $o->code('A');
  is($o->code, 'A     ', "character padding - $db_type");

  $o->code('C' x 50);
  is($o->code, 'C' x 6, "character truncation - $db_type");

  my $ouk;
  ok($ouk = MySQLiteObject->new(k1 => 1,
                                k2 => undef,
                                k3 => 3)->load, "load() uk 1 - $db_type");

  ok(!$ouk->not_found, "not_found() uk 1 - $db_type");

  is($ouk->id->[0], 1, "load() uk 2 - $db_type");
  is($ouk->name, 'John', "load() uk 3 - $db_type");

  ok($ouk->save, "save() uk 1 - $db_type");

  my $o2 = MySQLiteObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MySQLiteObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 22, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  $o2->set_status('foo');
  is($o2->get_status, 'foo', 'get_status()');
  $o2->set_status('active');
  eval { $o2->set_status };
  ok($@, 'set_status()');

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  my $clone = $o2->clone;
  ok($o2->start eq $clone->start, "clone() 1 - $db_type");
  $clone->start->set(year => '1960');
  ok($o2->start ne $clone->start, "clone() 2 - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MySQLiteObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MySQLiteObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  $o->nums([ 4, 5, 6 ]);
  ok($o->save, "save() 3 - $db_type");
  ok($o->load, "load() 4 - $db_type");

  is($o->nums->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o->nums->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o->nums->[2], 6, "load() verify 12 (array value) - $db_type");

  my @a = $o->nums;

  is($a[0], 4, "load() verify 13 (array value) - $db_type");
  is($a[1], 5, "load() verify 14 (array value) - $db_type");
  is($a[2], 6, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  ok($o->delete, "delete() - $db_type");

  $o = MySQLiteObject->new(name => 'John', id => 9);
  $o->save_col(22);
  ok($o->save, "save() 4 - $db_type");
  $o->save_col(50);
  ok($o->save, "save() 5 - $db_type");

  $ouk = MySQLiteObject->new(save_col => 50);
  ok($ouk->load, "load() aliased unique key - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, "alias_column() nonesuch - $db_type");

  # This is okay now
  #eval { $o->meta->alias_column(id => 'foo') };
  #ok($@, "alias_column() primary key - $db_type");

  $o = MySQLiteObject->new(id => 777);

  $o->meta->error_mode('fatal');

  $o->dbh->{'PrintError'} = 0;

  eval { $o->load };
  ok($@ && $o->not_found, "load() not found fatal - $db_type");

  my $old_table = $o->meta->table;

  $o->meta->table('nonesuch');

  eval { $o->load };
  ok($@ && !$o->not_found, "load() fatal - $db_type");

  eval { $o->save };
  ok($@, "save() fatal - $db_type");

  $o->meta->table($old_table);  
  $o->meta->error_mode('return');

  $o = MyMPKSQLiteObject->new(name => 'John');

  ok($o->save, "save() 1 multi-value primary key with generated values - $db_type");

  is($o->k1, 1, "save() verify 1 multi-value primary key with generated values - $db_type");
  is($o->k2, 2, "save() verify 2 multi-value primary key with generated values - $db_type");

  $o = MyMPKSQLiteObject->new(name => 'Alex');

  ok($o->save, "save() 2 multi-value primary key with generated values - $db_type");

  is($o->k1, 3, "save() verify 3 multi-value primary key with generated values - $db_type");
  is($o->k2, 4, "save() verify 4 multi-value primary key with generated values - $db_type");

  $o = MySQLiteObject->new(id => 9999); # no such id

  $o->meta->error_mode('fatal');

  eval { $o->load() };
  ok($@, "load() non-speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 1 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");

  $o->meta->default_load_speculative(1);

  ok(!$o->load(), "load() speculative implicit - $db_type");  
  ok(!$o->load(speculative => 1), "load() speculative explicit 2 - $db_type");
  eval { $o->load(speculative => 0) };
  ok($@, "load() non-speculative explicit 2 - $db_type");
}

BEGIN
{
  #
  # Postgres
  #

  my $dbh;

  eval 
  {
    $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_PG = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_private.rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
      $dbh->do('CREATE SCHEMA rose_db_object_private');
    }

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('CREATE TABLE rose_db_object_chkpass_test (pass CHKPASS)');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
    };

    our $PG_HAS_CHKPASS = 1  unless($@);

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  @{[ $PG_HAS_CHKPASS ? 'passwd CHKPASS,' : '' ]}
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bitz           BIT(5) NOT NULL DEFAULT B'00101',
  decs           DECIMAL(10,2),
  start          DATE,
  save           INT,
  nums           INT[],
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_private.rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  @{[ $PG_HAS_CHKPASS ? 'passwd CHKPASS,' : '' ]}
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bitz           BIT(5) NOT NULL DEFAULT B'00101',
  decs           DECIMAL(10,2),
  start          DATE,
  save           INT,
  nums           INT[],
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyPgObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('pg') }

    MyPgObject->meta->table('rose_db_object_test');

    MyPgObject->meta->columns
    (
      name     => { type => 'varchar', length => 32, overflow => 'truncate' },
      code     => { type => 'char', length => 6, overflow => 'truncate' },
      id       => { primary_key => 1, not_null => 1 },
      k1       => { type => 'int' },
      k2       => { type => 'int', lazy => 1 },
      k3       => { type => 'int' },
      ($PG_HAS_CHKPASS ? (passwd => { type => 'chkpass', alias => 'password' }) : ()),
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active', add_methods => [ qw(get set) ] },
      start    => { type => 'date', default => '12/24/1980', lazy => 1 },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      bitz     => { type => 'bitfield', bits => 5, default => 101, alias => 'bits' },
      decs     => { type => 'decimal', precision => 10, scale => 2 },
      #last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyPgObject->meta->add_unique_key('save');

    MyPgObject->meta->add_unique_key([ qw(k1 k2 k3) ]);

    MyPgObject->meta->add_columns(
      Rose::DB::Object::Metadata::Column::Timestamp->new(
        name => 'last_modified'));

    eval { MyPgObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyPgObject->meta->alias_column(save => 'save_col');

    eval { MyPgObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() no override');

    MyPgObject->meta->initialize(preserve_existing => 1);

    Test::More::is(MyPgObject->meta->column('id')->is_primary_key_member, 1, 'is_primary_key_member - pg');
    Test::More::is(MyPgObject->meta->column('id')->primary_key_position, 1, 'primary_key_position 1 - pg');
    Test::More::ok(!defined MyPgObject->meta->column('k1')->primary_key_position, 'primary_key_position 2 - pg');
    MyPgObject->meta->column('k1')->primary_key_position(7);
    Test::More::ok(!defined MyPgObject->meta->column('k1')->primary_key_position, 'primary_key_position 3 - pg');
  }

  #
  # MySQL
  #

  my $db_version;

  eval
  {
    my $db = Rose::DB->new('mysql_admin');
    $dbh = $db->retain_dbh() or die Rose::DB->error;
    $db_version = $db->database_version;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_MYSQL = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_test2');
    }

    # MySQL 5.0.3 or later has a completely stupid "native" BIT type
    my $bit_col1 = 
      ($db_version >= 5_000_003) ?
        q(bitz  BIT(5) NOT NULL DEFAULT B'00101') :
        q(bitz  BIT(5) NOT NULL DEFAULT '00101');

    my $bit_col2 = 
      ($db_version >= 5_000_003) ?
        q(bitz2  BIT(2) NOT NULL DEFAULT B'00') :
        q(bitz2  BIT(2) NOT NULL DEFAULT '0');

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           TINYINT(1) NOT NULL,
  flag2          TINYINT(1),
  status         VARCHAR(32) DEFAULT 'active',
  $bit_col1,
  $bit_col2,
  bitz3          BIT(4),
  decs           FLOAT(10,2),
  nums           VARCHAR(255),
  start          DATE,
  save           INT,
  enums          ENUM('foo', 'bar', 'baz') DEFAULT 'foo',
  ndate          DATE NOT NULL DEFAULT '0000-00-00',
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test2
(
  k1             INT NOT NULL,
  k2             INT NOT NULL,
  name           VARCHAR(32),

  UNIQUE(k1, k2)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyMySQLObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

    MyMySQLObject->meta->allow_inline_column_values(1);

    MyMySQLObject->meta->table('rose_db_object_test');

    MyMySQLObject->meta->columns
    (
      name     => { type => 'varchar', length => 32 },
      code     => { type => 'char', length => 6 },
      id       => { primary_key => 1, not_null => 1 },
      k1       => { type => 'int' },
      k2       => { type => 'int', lazy => 1 },
      k3       => { type => 'int' },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active', methods => [ qw(get_set get set) ] },
      start    => { type => 'date', default => '12/24/1980', lazy => 1 },
      ndate    => { type => 'date', not_null => 1, default => '0000-00-00' },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      enums    => { type => 'enum', values => [ qw(foo bar baz) ], default => 'foo' },
      bitz     => { type => 'bitfield', bits => 5, default => 101, alias => 'bits' },
      bitz2    => { type => 'bits', bits => 2, default => '0' },
      bitz3    => { type => 'bits', bits => 4 },
      decs     => { type => 'decimal', precision => 10, scale => 2 },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    eval { MyMySQLObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyMySQLObject->meta->alias_column(save => 'save_col');

    eval { MyMySQLObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() no override');

    MyMySQLObject->meta->add_unique_key('save');
    MyMySQLObject->meta->add_unique_key([ qw(k1 k2 k3) ]);

    MyMySQLObject->meta->initialize(preserve_existing => 1);

    Test::More::is(MyMySQLObject->meta->column('id')->is_primary_key_member, 1, 'is_primary_key_member - mysql');
    Test::More::is(MyMySQLObject->meta->column('id')->primary_key_position, 1, 'primary_key_position 1 - mysql');
    Test::More::ok(!defined MyMySQLObject->meta->column('k1')->primary_key_position, 'primary_key_position 2 - mysql');
    MyMySQLObject->meta->column('k1')->primary_key_position(7);
    Test::More::ok(!defined MyMySQLObject->meta->column('k1')->primary_key_position, 'primary_key_position 3 - mysql');

    package MyMPKMySQLObject;

    use Rose::DB::Object;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

    MyMPKMySQLObject->meta->table('rose_db_object_test2');

    MyMPKMySQLObject->meta->columns
    (
      k1          => { type => 'int', not_null => 1 },
      k2          => { type => 'int', not_null => 1 },
      name        => { type => 'varchar', length => 32 },
    );

    MyMPKMySQLObject->meta->primary_key_columns('k1', 'k2');

    MyMPKMySQLObject->meta->initialize;

    my $i = 1;

    MyMPKMySQLObject->meta->primary_key_generator(sub
    {
      my($meta, $db) = @_;

      my $k1 = $i++;
      my $k2 = $i++;

      return $k1, $k2;
    });
  }

  #
  # Informix
  #

  eval
  {
    $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_INFORMIX = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bitz           VARCHAR(5) DEFAULT '00101' NOT NULL,
  decs           DECIMAL(10,2),
  nums           VARCHAR(255),
  start          DATE,
  save           INT,
  names          SET(VARCHAR(64) NOT NULL),
  last_modified  DATETIME YEAR TO FRACTION(5),
  date_created   DATETIME YEAR TO FRACTION(5)
)
EOF

    $dbh->commit;
    $dbh->disconnect;

    # Create test subclass

    package MyInformixObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('informix') }

    MyInformixObject->meta->allow_inline_column_values(1);

    MyInformixObject->meta->table('rose_db_object_test');

    MyInformixObject->meta->columns
    (
      name     => { type => 'varchar', length => 32, overflow => 'truncate' },
      code     => { type => 'char', length => 6, overflow => 'truncate' },
      id       => { type => 'serial', primary_key => 1, not_null => 1 },
      k1       => { type => 'int' },
      k2       => { type => 'int', lazy => 1 },
      k3       => { type => 'int' },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active', add_methods => [ qw(get set) ] },
      start    => { type => 'date', default => '12/24/1980', lazy => 1 },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      bitz     => { type => 'bitfield', bits => 5, default => 101, alias => 'bits' },
      decs     => { type => 'decimal', precision => 10, scale => 2 },
      names    => { type => 'set' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'datetime year to fraction(5)' },
    );

    eval { MyInformixObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyInformixObject->meta->prepare_options({ix_CursorWithHold => 1});    

    MyInformixObject->meta->alias_column(save => 'save_col');

    eval { MyInformixObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() no override');

    MyInformixObject->meta->add_unique_key('save');
    MyInformixObject->meta->add_unique_key([ qw(k1 k2 k3) ]);

    MyInformixObject->meta->initialize(preserve_existing => 1);

    Test::More::is(MyInformixObject->meta->column('id')->is_primary_key_member, 1, 'is_primary_key_member - informix');
    Test::More::is(MyInformixObject->meta->column('id')->primary_key_position, 1, 'primary_key_position 1 - informix');
    Test::More::ok(!defined MyInformixObject->meta->column('k1')->primary_key_position, 'primary_key_position 2 - informix');
    MyInformixObject->meta->column('k1')->primary_key_position(7);
    Test::More::ok(!defined MyInformixObject->meta->column('k1')->primary_key_position, 'primary_key_position 3 - informix');
  }

  #
  # SQLite
  #

  eval 
  {
    $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_SQLITE = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_test2');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  k1             INT,
  k2             INT,
  k3             INT,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bitz           VARCHAR(5) DEFAULT '00101' NOT NULL,
  decs           DECIMAL(10,2),
  start          DATE,
  save           INT,
  nums           VARCHAR(255),
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test2
(
  k1             INT NOT NULL,
  k2             INT NOT NULL,
  name           VARCHAR(32),

  UNIQUE(k1, k2)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MySQLiteObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('sqlite') }

    MySQLiteObject->meta->table('rose_db_object_test');

    MySQLiteObject->meta->columns
    (
      name     => { type => 'varchar', length => 32, overflow => 'truncate' },
      code     => { type => 'char', length => 6, overflow => 'truncate' },
      id       => { primary_key => 1, not_null => 1 },
      k1       => { type => 'int' },
      k2       => { type => 'int', lazy => 1 },
      k3       => { type => 'int' },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active', add_methods => [ qw(get set) ] },
      start    => { type => 'date', default => '12/24/1980', lazy => 1 },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      bitz     => { type => 'bitfield', bits => 5, default => 101, alias => 'bits' },
      decs     => { type => 'decimal', precision => 10, scale => 2 },
      #last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MySQLiteObject->meta->add_unique_key('save');

    MySQLiteObject->meta->add_unique_key([ qw(k1 k2 k3) ]);

    MySQLiteObject->meta->add_columns(
      Rose::DB::Object::Metadata::Column::Timestamp->new(
        name => 'last_modified'));

    MySQLiteObject->meta->column('id')->add_trigger(inflate => sub { defined $_[1] ? [ $_[1] ] : undef });
    MySQLiteObject->meta->column('id')->add_trigger(deflate => sub { ref $_[1] ? @{$_[1]}  : $_[1] });

    my $pre_inited = 0;
    MySQLiteObject->meta->pre_init_hook(sub { $pre_inited++ });

    eval { MySQLiteObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');
    Test::More::is($pre_inited, 1, 'meta->pre_init_hook()');

    MySQLiteObject->meta->alias_column(save => 'save_col');

    eval { MySQLiteObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() no override');

    MySQLiteObject->meta->initialize(preserve_existing => 1);

    Test::More::is(MySQLiteObject->meta->column('id')->is_primary_key_member, 1, 'is_primary_key_member - sqlite');
    Test::More::is(MySQLiteObject->meta->column('id')->primary_key_position, 1, 'primary_key_position 1 - sqlite');
    Test::More::ok(!defined MySQLiteObject->meta->column('k1')->primary_key_position, 'primary_key_position 2 - sqlite');
    MySQLiteObject->meta->column('k1')->primary_key_position(7);
    Test::More::ok(!defined MySQLiteObject->meta->column('k1')->primary_key_position, 'primary_key_position 3 - sqlite');

    package MyMPKSQLiteObject;

    use Rose::DB::Object;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('sqlite') }

    MyMPKSQLiteObject->meta->table('rose_db_object_test2');

    MyMPKSQLiteObject->meta->columns
    (
      k1          => { type => 'int', not_null => 1 },
      k2          => { type => 'int', not_null => 1 },
      name        => { type => 'varchar', length => 32 },
    );

    MyMPKSQLiteObject->meta->primary_key_columns('k1', 'k2');

    MyMPKSQLiteObject->meta->initialize;

    my $i = 1;

    MyMPKSQLiteObject->meta->primary_key_generator(sub
    {
      my($meta, $db) = @_;

      my $k1 = $i++;
      my $k2 = $i++;

      return $k1, $k2;
    });
  }
}

END
{
  # Delete test table

  if($HAVE_PG)
  {
    # Postgres
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_private.rose_db_object_test');
    $dbh->do('DROP SCHEMA rose_db_object_private CASCADE');

    $dbh->disconnect;
  }

  if($HAVE_MYSQL)
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_test2');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');

    $dbh->disconnect;
  }

  if($HAVE_SQLITE)
  {
    # SQLite
    my $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_test2');

    $dbh->disconnect;
  }
}
