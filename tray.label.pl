#!/usr/bin/env perl

        ##  # #  #       #                                                        
       #  # # #    ###  #### ###  ###  #  #                                       
       #### # #  # #  #  #   #   #  #  # #                                       
       #  # # #  # #  #  ### #    ###   #                                        
                                      ##  
##################################################
#                                                #
#              A L L I N T R A Y                 #
#      Clock, CPU/RAM usage, volume control      #
#                                                #
##################################################
#  Premek Vyhnal <premysl.vyhnal gmail.com>      #
#                                                #
#  Used:                                         #
#  volwheel.pl (Olivier Duclos <oliwer@free.fr>) #
#  gkrellm-bfm plugin                            #
##################################################

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version. 
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details. 
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 
# USA


use strict;
use warnings;										# přidat ukazatel hlasitosti
use Gtk2 '-init';
use Gtk2::TrayIcon;
#use Gtk2::ProgressBar; ale chci ho!!!!!

our $DELAY = shift (@ARGV) || 1000;
our $MIXER = shift (@ARGV) || "alsamixergui";
our $PROCSTAT = shift (@ARGV) || "/proc/stat";
our $PROCNET = shift (@ARGV) || "/proc/net/dev";
# Tray icon
#my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file("/usr/share/icons/gnome/24x24/apps/gnome-audio.png");
#my $icon = Gtk2::Image->new_from_pixbuf($pixbuf);
my $trayicon = Gtk2::TrayIcon->new("volwheel");
my $tooltip= Gtk2::Tooltips->new;
my $eventbox = Gtk2::EventBox->new;

#$eventbox->add($icon);
my $label= Gtk2::Label->new(`date +"%H:%M"`); # date
$eventbox->add($label);

$trayicon->add($eventbox);
$eventbox->signal_connect( 'button_release_event', \&click_handler );
$eventbox->signal_connect( 'scroll_event', \&scroll_handler );
$trayicon->show_all;

Glib::Timeout->add($DELAY, \&update);

open(STAT,$PROCSTAT);
open(NET,$PROCNET);
my $lastload=0;
my $lasttotal=0;
my $lastrx=0;
my $lasttx=0;

&update;

Gtk2->main();

sub cpu {
	seek STAT,0,0;
	<STAT> =~ m/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+).*$/;

	my $load = $1+$2+$3;
	my $total = $load+$4+$5+$6+$7;

	my $ret;

	if ($lasttotal==0){ $ret=0; }
	elsif (($total - $lasttotal) <= 0){ $ret=100; } # bez tohohle to obcas zdechne
	else { $ret = int((100 * ($load - $lastload))/($total - $lasttotal)); }

	($lastload, $lasttotal) = ($load,$total);
	return $ret;
}

sub net {
	seek NET,0,0;
	my @a=<NET>;
	@a=grep(/^\s*eth0/,@a);
	(my $rx, my $tx) = $a[0] =~ m/^\s*eth0:(\d+)\s+(?:\d+\s+){7}(\d+).*$/;
	
	my @ret;
	@ret = (int(($rx-$lastrx)/1024/($DELAY/1000)), int(($tx-$lasttx)/1024/($DELAY/1000)));
	@ret = (0,0) if ($lastrx==0);
	($lastrx, $lasttx) = ($rx, $tx);
	return (@ret);
}


sub mem {
	`free` =~ m/Mem:\s*(\d+).*\n.*cache:\s+(\d+)/;
	return 100*$2/$1;
}

sub update {
	my @cas=localtime(time);
	my $mem=&mem;
	my $cpu=&cpu;
	(my $nrx, my $ntx) = &net;
	$tooltip->set_tip($trayicon, sprintf("%d.%d %d:%02d\nRAM: %d%%\nCPU: %d%%\nUPL: %d kB/s\nDWN: %d kB/s" , $cas[3],$cas[4]+1,$cas[2],$cas[1],$mem,$cpu,$ntx,$nrx,));
	$label->set_text(sprintf(" %03d | %03d | %03d | %03d | %d:%02d " , $ntx, $nrx, $mem,$cpu,$cas[2],$cas[1]));
	1; # proč? .)
}




# S U B S #

sub volup {
    system "amixer set Master 3%+ > /dev/null";
}
sub voldown {
    system "amixer set Master 3%- > /dev/null";
}
sub mute {
	system "amixer set Master toggle> /dev/null";
}

sub launchMixer {
    exec $MIXER unless fork;
}

sub click_handler {
    my ($check, $event) = @_;
    
    if (1 eq $event->button) {
        &launchMixer;
    }
    elsif (2 eq $event->button) {
		&mute;
    }
    elsif (3 eq $event->button) {
		&popup;
    }
}

sub scroll_handler {
    my ($check, $event) = @_;
    
    if ("up" eq $event->direction) {
        &volup;
    }
    elsif ("down" eq $event->direction) {
        &voldown;
    }
	&update;
}

sub popup {
    my $item_factory = Gtk2::ItemFactory->new("Gtk2::Menu", '<main>', undef);
    my $popup_menu = $item_factory->get_widget('<main>');
    my @menu_items = (
#               { path => '/About',       item_type => '<Item>', callback => \&about_dialog},
               { path => '/Exit',        item_type => '<Item>', callback => \&out}
             );

    $item_factory->create_items(undef, @menu_items);
    $popup_menu->show_all;
    $popup_menu->popup(undef, undef, undef, undef, 0, 0);
}

#sub about_dialog {
#    my $about = Gtk2::AboutDialog->new;
#    $about->set_name("VolWheel");
#    $about->set_version($VERSION);
#    $about->set_copyright("Copyright (c) Olivier Duclos 2007");
#    $about->set_comments("Set volume with the mousewheel. Sweet!");
#    $about->set_website("oliwer\@hedinux.org");
##    $about->set_logo($pixbuf);
#    $about->run;
#    $about->destroy;
#}

sub out {
	close(STAT);
	close(NET);
    Gtk2->main_quit;
}
