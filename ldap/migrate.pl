#!/usr/bin/perl -w
#
# This was adapted from a script on the redhat-ds wiki,
# it now at least attempts to handle openldap's "objectidentifier" 
# macros --Kevin Goess 12/2005
#
# this is a quick perl script to convert OpenLDAP schema files
# to FDS ldif (schema) files.  it is probably not anywhere near
# useful, but it did allow me to convert a few of my .schema
# files and have FDS successfully start with them.
#
# -Nathan Benson <tuxtattoo@gmail.com>
#

use strict;

die "usage: $0 <openldap.schema>\n" unless my $file = $ARGV[0];
die "$! '$file'\n" unless -e $file;

my $start;

print "dn: cn=schema\n";

my (%objectidentifier, $objidmatch);

open SCHEMA, $file;
while (<SCHEMA>)
{
        next if /^(#|$)/;
        
        #see http://www.openldap.org/doc/admin22/schema.html#OID%20Macros
        if ($objidmatch && /($objidmatch:| $objidmatch )/) 
        {
            s/($objidmatch):/$objectidentifier{$1}./;

            #boo, this doesn't work for stuff in quoted fields
            s/\s($objidmatch)\s/ $objectidentifier{$1} / unless /DESC/;
        }

        if (/^\s*objectidentifier\s+(\S+)\s+(\S+)/) 
        {
            $objectidentifier{$1} = $2;
            $objidmatch = join('|',keys(%objectidentifier));
        }
        
        
        if (/^(objectclass|attributetype)\s/i)
        {
                print "\n" if ($start);
                chomp;


                $_     =~ s/^objectclass/objectclasses:/i;
                $_     =~ s/^attributetype/attributetypes:/i;
                $_     =~ s/(\t|\s)/ /;


                $start = 1;
                print;
        }
        elsif ((/^\s*\w/) && ($start))
        {
                chomp;
                $_     =~ s/^(\s*)/ /;
                print;
        }
        elsif (/^\s*\)\s*$/ && $start) {
            print ')';
        }
}
close SCHEMA;
