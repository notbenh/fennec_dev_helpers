#!/usr/bin/perl 
use strict;
use warnings;
use Data::Dumper;
use Getopt::Std;
use File::Slurp;

=head1 USEAGE

fennec_tb_wrapper_create.pl -t Test::Something -f Fennec::Assert::Wrapper::Something -w "something_ok is_something"

  -t : (required) the package that you are going to wrap, expected to be based on Test::Builder 
       and the package name is expected to be 'Test::.*'.
  -f : The Fennec package that you are planning on creating, if not specified it will be build to be 
       Fennec::Assert::Wrapper::Something for Test::Something.
  -w : The list of fuctions that are exported by Test::Something that you would like to wrap. If given it 
       is expected to be a single string split on whitespace or ','. If not given it defaults to 
       @Test::Something::EXPORT. Any item that Test::Something can not do will be silently ignored.

  [module_starter]
  -a : (required) your author name
  -e : (required) your email address

=cut

my %opts;
getopts('f:t:w:a:e:', \%opts);  # options as above. Values in %opts

die 'No Test package specified via -t' unless defined $opts{t};
eval sprintf( q{require %s}, $opts{t}) 
   or die $opts{t}, q{ was not able to be loaded, please check that it is installed};

my $fennec_prefix = q{Fennec::Assert::Wrapper};
$opts{f} = join '::', $fennec_prefix, $opts{t} =~ m/Test::(.*)/;

$opts{w} = (defined $opts{w} ) 
         ? [ grep{$opts{t}->can($_)} grep{length} map{s/\s+//g;$_} split /(\s+|,)/, $opts{w} ]
         : [ eval sprintf q{@%s::EXPORT}, $opts{t} ]
         ;

die 'Please give an author name via -a' unless defined $opts{a};
die 'Please give an author email address via -e' unless defined $opts{e};

#---------------------------------------------------------------------------
#  Module
#---------------------------------------------------------------------------
my $module_starter = sprintf q{module-starter --module='%s' --author='%s' --email='%s' -mb},
                             $opts{f}, $opts{a}, $opts{e} ;
print `$module_starter`;

my $module_dir = $opts{f};
$module_dir =~ s/::/-/g;

die qq{$module_dir does not exist} unless -e $module_dir;
chdir $module_dir;

print `fennec_init && fennec_scaffold.pl`;

#---------------------------------------------------------------------------
#  write lib
#---------------------------------------------------------------------------
my $module_package_path = sprintf q{%s.pm}, join '/', 'lib', split /::/, $opts{f};
#warn $module_package_path;
#warn `more $module_package_path`;

my $test_head = sprintf q|
use Fennec::Assert;
use Fennec::Output::Result;
require %s;
|, $opts{t};

my $test_block = sprintf q|
for my $name ( qw{%s} ) {
    no strict 'refs';
    next unless %s->can( $name );
    tester( $name => tb_wrapper( \&{ '%2$s::' . $name }));
};

1;                                                                                                                                                                                                                                                                                         
|,
   join( ' ', @{$opts{w}} ),
   $opts{t},
;

my $wrapped_functions = sprintf q|
=head1 WRAPPED FUNCTIONS

=over 4

%s

=back
|, 
   join( qq{\n\n}, sort map{ sprintf qq{=item $_()} } @{$opts{w}} ),
;


my $lib = read_file( $module_package_path );
$lib =~ s/The great new .*!/Fennec wrapper for L<$opts{t}>/;
$lib =~ s/(=head1 NAME)/$test_head\n$1/;
$lib =~ s/\n\=head1 SYNOPSIS.*}/$test_block\n$wrapped_functions/ms;
$lib =~ s/1; # End of.*//;
$lib =~ s/\n\n\n+/\n\n/g;

write_file( $module_package_path, $lib );
#warn `more $module_package_path`;


#---------------------------------------------------------------------------
#  write test
#---------------------------------------------------------------------------
my $module_test_path    = sprintf q{%s.pm}, join '/', 't', split /::/, $opts{f};
#warn $module_test_path;
#warn `more $module_test_path`;
write_file( $module_test_path, sprintf q|package TEST::%s;
use strict;
use warnings;
use Fennec;

require_or_skip %s;

tests load {
    use_ok( '%1$s' );
    can_ok( $self, qw{%s
                     });
};
|,
   $opts{f},
   $opts{t},
   join( qq{\n                      }, @{$opts{w}} ),
);
#warn `more $module_test_path`;


#---------------------------------------------------------------------------
#  Clean up module_build tests
#---------------------------------------------------------------------------
unlink map{ "t/$_"} qw{00-load.t boilerplate.t pod-coverage.t  pod.t};
write_file( 'MANIFEST',
            join qq{\n}, 
             ( grep{! m{t/(00-load|boilerplate|pod-coverage|pod)\.t} } 
               split /\n/, read_file('MANIFEST')
             ),
             q{t/Fennec.t},
             $module_test_path,
);
#print read_file('MANIFEST');

#---------------------------------------------------------------------------
#  run tests
#---------------------------------------------------------------------------
$|++;
#print `perl Build.PL && ./Build && ./Build test`;




