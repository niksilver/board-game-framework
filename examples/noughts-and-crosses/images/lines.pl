#!/usr/bin/perl


$url = $ARGV[0];

$result = system("wget -O index.html $url");
print "result = $result\n";

open(OF, "index.html");

while ($line = <OF>) {
    chomp $line;

    # Find the username
    if ($line =~ /<title>.*\|.*\|.*<\/title>/) {
        $line =~ s/[^|]*\|\s*//;
        $line =~ s/\s*\|.*//;
        $name = $line;
    }

    # Find the URL
    if ($line =~ /"url":.*_h\.jpg/) {
        $line =~ s/.*"([^"]*_h\.jpg).*/$1/;
        $line =~ s/\\//g;
        $image = "https:$line";
    }
}

print "Name = $name\n";
print "Image = $image\n";

close(OF);
