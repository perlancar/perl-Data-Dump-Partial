#!perl -T

use strict;
use warnings;

use Test::More tests => 2;
use Data::Dump::Partial qw(dump_partial dumpp);

#use lib "./t";
#require "testlib.pl";

is(dump_partial(1), 1, "export dump_partial");
is(dumpp(1), 1, "export dumpp");

is(dumpp("a" x  10), "a" x 10, "untruncated scalar");
is(dumpp("a" x 100), '"' . ("a" x 29) . '..."', "truncated scalar");
