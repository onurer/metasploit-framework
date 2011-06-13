# $Id$
##

##
# ## This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##

require 'msf/core'
require 'rex'
require 'msf/core/post/common'
require 'msf/core/post/file'
require 'msf/core/post/linux/priv'

class Metasploit3 < Msf::Post

	include Msf::Post::Common
	include Msf::Post::File
	include Msf::Post::Priv


	def initialize(info={})
		super( update_info( info,
				'Name'          => 'Linux Gather Virtual Environment Detection',
				'Description'   => %q{
					This module attempts to determine whether the system is running
					inside of a virtual environment and if so, which one. This
					module supports detectoin of Hyper-V, VMWare, VirtualBox, Xen,
					and QEMU/KVM.},
				'License'       => MSF_LICENSE,
				'Author'        => [ 'Carlos Perez <carlos_perez[at]darkoperator.com>'],
				'Version'       => '$Revision$',
				'Platform'      => [ 'linux' ],
				'SessionTypes'  => [ 'shell' ]
			))
	end

	# Run Method for when run command is issued
	def run
		print_status("Gathering System info ....")
		vm = nil
		loaded_modules = cmd_exec("/sbin/lsmod")
		dmesg = cmd_exec("dmesg")
		proc_scsi = read_file("/proc/scsi/scsi")

		if is_root?
			dmi_info = cmd_exec("/usr/sbin/dmidecode")
		end

		# Check Modules
		case loaded_modules.gsub("\n", " ")
		when /vboxsf|vboxguest/i
			vm = "VirtualBox"
		when /vmw_ballon|vmxnet|vmw/i
			vm = "VMware"
		when /xen-vbd|xen-vnif/
			vm = "Xen"
		when /virtio_pci|virtio_net/
			vm = "Qemu/KVM"
		when /hv_vmbus|hv_blkvsc|hv_netvsc|hv_utils|hv_storvsc/
			vm = "MS Hyper-V"
		end

		# Check SCSI Driver
		if not vm
			case proc_scsi.gsub("\n", " ")
			when /vmware/i
				vm = "VMware"
			when /vbox/
				vm = "VirtualBox"
			end
		end

		# Check using lspci
		if not vm
			case get_sysinfo[:distro]
			when /oralce|centos|suse|redhat|mandrake|slackware|fedora/
				lspci_data = cmd_exec("/sbin/lspci")
			when /debian|ubuntu/
				lspci_data = cmd_exec("/usr/bin/lspci")
			else
				lspci_data = cmd_exec("lspci")
			end

			case lspci_data.gsub("\n", " ")
			when /vmware/i
				vm = "VMware"
			when /virtualbox/i
				vm = "VirtualBox"
			end
		end

		# Xen bus check
		if not vm
			if cmd_exec("ls -1 /sys/bus").split("\n").include?("xen")
				vm = "Xen"
			end
		end

		# Check using lscpu
		if not vm
			case cmd_exec("lscpu")
			when /Xen/
				vm = "Xen"
			when /KVM/
				vm = "KVM"
			when /Microsoft/
				vm = "MS Hyper-V"
			end
		end

		# Check dmesg Output
		if not vm
		case dmesg
		when /vboxbios|vboxcput|vboxfacp|vboxxsdt|(vbox cd-rom)|(vbox harddisk)/i
				vm = "VirtualBox"
			when /(vmware virtual ide)|(vmware pvscsi)|(vmware virtual platform)/i
				vm = "VMware"
			when /(xen_mem)|(xen-vbd)/i
				vm =  "Xen"
			when /(qemu virtual cpu version)/i
				vm = "Qemu/KVM"
			end
		end

		if vm
			print_good("This appears to be a #{vm} Virtual Machine")
		else
			print_status("This appears to be a Physical Machine")
		end

	end



end