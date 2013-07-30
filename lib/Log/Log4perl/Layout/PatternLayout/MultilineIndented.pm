#!/usr/bin/perl

package Log::Log4perl::Layout::PatternLayout::MultilineIndented;

use base qw(Log::Log4perl::Layout::PatternLayout); 

# find the position of last occurrence of a substring
# within a string

# using an anonymous sub to make it inaccessible from outside
# very private ;-)

my $find_last_pos = sub {               
    my ($str, $substr) = @_;
    my $last_pos;

    return undef if ! defined $str || ! defined $substr;

    return 0 if $substr eq '';

    my $pos = 0;
    my $len_substr = length($substr);
    while ( ($pos = index($str, $substr, $pos)) != -1 ) {
        $last_pos = $pos;
        $pos += $len_substr;
    }
    return $last_pos;
};


# render the output of a multiline log message

###########################################
sub render {
###########################################
    my($self, $message, $category, $priority, $caller_level) = @_; 

    my @lines = split /\r?\n/, $message; 
    $caller_level = 0 unless defined $caller_level; 
    my $result = ''; 

    return $result if scalar @lines == 0;

    # full rendering/formatting for first line
    my $first_msg = shift @lines;
    $result .= $self->SUPER::render( $first_msg, $category, $priority, $caller_level + 1 ); 

    if ( scalar @lines ) {
        # for all lines following we override all characters before of the message
        # provided by the user (usually date, category ...) by blanks
        my $indent_pos = $find_last_pos->($result, $first_msg);
        my $rendered_line; 
        my $blanks = ' ' x $indent_pos;
        for my $line ( @lines ) { 
            $rendered_line = $self->SUPER::render( $line, $category, $priority, $caller_level + 1 ); 

            # replace characters up to $indent_pos with blanks
            substr($rendered_line, 0, $indent_pos, $blanks);

            $result .= $rendered_line;
        }
    }
    return $result; 
} 

1; 

__END__

= head1 NAME

    Logger::Layout::PatternLayout::MultilineIndented

=head1 SYNOPSIS

    use Logger::Layout::PatternLayout::MultilineIndented;

    my $layout = Logger::Layout::PatternLayout::MultilineIndented->new("%d > %m %n");

    NOTE: you have to set %n for the layout.

=head1 DESCRIPTION

C<Logger::Layout::PatternLayout::MultilineIndented> is a subclass
of Log4perl's PatternLayout and is helpful if you send multiline
messages to your appenders which normally appear as

    2007/04/04 23:59:01 > This is
    a message with
    multiple lines

and you want them to appear as 

    2007/04/04 23:59:01 > This is
                          a message with
                          multiple lines

This layout class is like C<Logger::Layout::PatternLayout::Multiline> 
It simply splits up the incoming message into
several lines by line breaks. It renders the first line of the message 
with the given PatternLayout and indents the following lines properly.

=head1 HOW IT WORKS and a CAVEAT

The algorithm is very simple. 
The first line is rendered according to the pattern you provided. 
The rendered result string is used to calculate the last position 
of the provided first line in the rendered result string. 
All following lines are rendered too, but in a second step all characters 
up to the calculated position are replaced by blanks and the result is output.

The Caveat :

If your pattern is "%d > %m This is%n" and you log

    $logger->info(<<'EOF_MSG');
    This is
    a message with
    multiple lines
    EOF_MSG

the last position of the first message line 'This is' is searched
within the first rendered result line, which is 

    "2013/05/02 14:40:24 > This is This is\n"
                                   |
                                 last position of first message line 
The next rendered line would be

    "2013/05/02 14:40:24 > a message with This is\n"
                                   |
                                last position of first message line 

and all characters up to the last position of the first message line
will be replaced by blanks.

    "                              e with This is\n"
                                   |
                                 last position of first message line 
                                   

In your log file appears

    2013/07/30 18:04:00 > This is This is
                                  e with This is
                                   lines This is

Usually %m is the last item in your layout pattern and the position of the
message in the rendered output line can be determined without problems, 
so it should not be an issue in most cases.




=head1 LICENSE

Copyright 2002-2013 by Wolfgang Pecho E<lt>wolfgang_pecho@gmx.deE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 
