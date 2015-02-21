#!/bin/perl

require "/usr/local/lib/bclib.pl";
require "$bclib{home}/bc-private.pl";

# --stop=num: stop at this chunk

# see README for file format

defaults("stop=1");

# setting $tot to $limit so first run inside loop increments chunk
# TODO: $limit should be an option
my($limit) = 25e+9;

my($tot) = $limit;
my($count);

while (<>) {
  chomp;
  my($orig) = $_;

  if (++$count%100000==0) {debug("COUNT: $count");}

  # if we've gone over limit (or first run), move on to next chunk
  if ($tot>=$limit) {
    $chunk++;
    if ($chunk > $globopts{stop}) {last;}
    debug("STARTING CHUNK: $chunk");
    $tot=0;
    close(A);
    close(B);
    open(A,">filelist$chunk.txt")||die("Can't open, $!");
    open(B,">statlist$chunk.txt")||die("Can't open, $!");
    # TODO: replace below w zpaq (which requires hardlinks, non trivial)
  }

  my(%file);

  # TODO: in theory, could grab current file size using "-s"
  ($file{mtime},$file{size},$file{name}) =  split(/\s+/, $_, 3);

  # silently ignore directories, device files, etc
  if (-d $file{name} || -c $file{name} || -b $file{name} || -S $file{name}) {
    next;
  }

  # TODO: this might slow things down excessively, even with caching
  unless (-f $file{name} || -l $file{name}) {
    warn "NO SUCH FILE: $file{name}";
    next;
  }

  $tot+= $file{size};

  # NOTE: to avoid problems w/ filesizes > $limit, we add to chunk
  # first and THEN check for overage
  print A "$file{name}\n";
  print B "$orig\n";
}

close(A); close(B);

# TODO: really unhappy about this, should be able to do this in program
system ("sort statlist1.txt -o statlist1.txt");

debug("Used $count files to meet total");

# TODO: check zpaq errors
