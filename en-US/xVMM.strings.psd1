ConvertFrom-StringData @'
###PSLOC 
# Common
NoKeyFound = No Localization key found for ErrorType: {0}
AbsentNotImplemented = Ensure = Absent is not implemented!
ModuleNotFound = Module '{0}' not found in list of available modules.
TestFailedAfterSet = Test-TargetResource returned false after calling set.
RemoteConnectionFailed = Remote PowerShell connection to Server '{0}' failed.
TODO = ToDo. Work not implemented at this time. 
Unsupported = Unsupported configuration on {0}.

# VMM 
AllSwitchParametersRequired = All parameters must be supplied for Set-TargetResource.
BackupNetworkMustMatchLogical = BackupLogicalNetworkMatch must not be the same as LogicalNetworkMatch.
ClassificationNotFound = We didn't find a storage classification: '{0}'. Add the classification before running this resource.
CustomPropertyMemberNotFound = CustomProperty: '{0}' does not contain the member type: '{1}'.
CustomPropertyNotFound = Custom Property: '{0}' not found on object: '{1}' for member type: '{2}'.
CustomPropertyNotFound2 = CustomProperty: '{0}' not found.
CustomPropertyObjectInvalidReturn = '{0}' of member type: '{1}' returned back more than one record.
CustomPropertyObjectNotFound = Object: '{0}' of member type: '{1}' was not found.
DontRemoveVMMServer = VMM Console should not be removed from a VMM Management Server!
EndIPNotInSubnet = The end address '{0}' is not in the subnet '{1}'.
FailedToConnectToVMMServer = "Failed connecting to VMM server {0}"
FailedToGetSwitch = Failed to get VMM Switch/Port data from VMM Server '{0}'
FailedToSetSubnet = Failed to set Subnet/VLAN to '{0}'.
FirstIPIsGateway = The first address of a subnet on a VM Network using Network Virtualization is reserved for the gateway.
GatewayNotInSubnet = The gateway address '{0}' is not in the subnet '{1}'.
HostClusterNotFound = We didn't find the host cluster '{0}'!
HostGroupNotFound = Could not find HostGroup named '{0}'.
InvalidAddress = The Subnet '{0}' contains an invalid IP Address/Prefix value.
InvalidDNSIP = The DNS Server address '{0}' is not a valid IP address.
InvalidEndIPRange = IPAddressRange end address '{0}' is invalid.
InvalidEnsureValue = Unexpected value for the variable Ensure!
InvalidGatewayIP = Gateway address '{0}' is invalid.
InvalidGatewayMetric = Gateway metric must be a number between 1 and 9999.
InvalidIPRangeFormat = IPAddressRange string is not in the proper format. Should be: 'StartIP-EndIP'.
InvalidIsolationIPv4 = {0} VM Network Isolation was specified, but the VM Network '{1}' is IPv6.
InvalidIsolationIPv6 = {0} VM Network Isolation was specified, but the VM Network '{1}' is IPv4.
InvalidPortFormat = Virtual Port string is not properly formatted. Should be in the format: 'VirtualPortName;PortClassification;NetworkAdapterPortProfile'.
InvalidSecondVlan = The SecondaryVlanId '{0}' is not a valid value.
InvalidStartIPRange = IPAddressRange start address '{0}' is invalid.
InvalidSubnet = The Subnet '{0}' contains an invalid IP Address/Prefix value.
InvalidVlan = The VlanId '{0}' is not a valid value.
InvalidWINSIP = The WINS Server address '{0}' is not a valid IP address.
IsolationIPPoolMustUseLogicalNetwork = For networks using VLAN-based isolation you must create the Static IP Pool on the Logical Network.
LoadBalancerNotFound = Load Balancer with name '{0}' was not found.
LibraryServerNotFound = Library Server with name '{0}' was not found!
LibraryShareNotFound = Library Share with name '{0}' not found.
LocalSwitchNotFound = Unable to find VMM Logical Switch named '{0}'.
LogicalNetworkMatchNotDisabled = AutomaticLogicalNetworkCreation cannot be enabled when LogicalNetworkMatch is set to 'Disabled'.
LogicalNetworkNoResources = The Logical Network specified does not have any available resources to create a subnet for this VM Network.
LogicalNetworkNotFound = Could not find Logical Network named '{0}'.
LogicalSwitchInUse = The Logical Switch cannot be removed because there are resources dependent on it.
MultipleNetworksFound = Found multiple VM Networks named '{0}' associated with the Logical Network '{1}'.
MultipleNonIsolationNetworks = There can only be one Non-Isolated VM Network per Logical Network.
MustSpecifyNetworkAndLogicalNetworkProtocol = The IsolationVMNetworkProtocol and IsolationLogicalNetworkProtocol parameters must be specified.
MustSpecifySiteSubnet = Must specify the Network Site and Subnet/VLAN when creating a VM Network on a PVLAN-based Logical Network.
MustSpecifySiteSubnetOrAutoCreate = Must specify the Network Site and Subnet/VLAN or use AutoCreateSubnet when creating a VM Network on a VLAN-based Logical Network.
NetworkAdapterPortNotFound = Unable to find Network Adapter Port Profile named '{0}'.
NetworkSiteInvalidFormat = Network Site '{0}' is not properly formatted. Should be like: 'SiteName;LogicalNetwork'.
NetworkSiteNotFound = Unable to find Network Site named '{0}' on Logical Network '{1}'
NetworkSiteNotFound2 = Unable to find Network Site on Logical Network '{1}'
NetworkVirtualizationRequiredIsolation = To use protocol-based isolation for VM Networks, Network Virtualization must be enabled on the Logical Network.
NetworkVirtualizationRequiredMultiple = Network Virtualization is required to create more than one VM Network on this Logical Network.
NetworkVirtualizationRequiredSubnet = To specify VMSubnets, Network Virtualization must be enabled on the Logical Network.
NoIP4ProtocolError = Unable to use the specified Isolation Protocol. The Logical Network specified does not contain any IPv4 Subnets.
NoIP6ProtocolError = Unable to use the specified Isolation Protocol. The Logical Network specified does not contain any IPv6 Subnets.
NoIsolationStaticIPPool = Cannot create a Static IP Address Pool on a VM Network using No Isolation.
NoNetworkSitesFound = The Logical Network '{0}' does not contain any Network Sites.
PortClassificationNotFound = Unable to find Port Classification named '{0}'.
PortProfileSetNotFound = Unable to get the specified Port Profile Set. Port: '{0}', LogicalSwitch '{1}'.
ProtectionUnitNotImplement = ProtectionUnit member type is not implemented.
PreCreatedStorage = Storage should have been pre-created. Failing.
ResEndIPNotInSubnet = IP Reservation range end address '{0}' is not in the subnet '{1}'.
ResIPNotInSubnet = IP Reservation address '{0}' is not in the subnet '{1}'.
ResStartIPNotInSubnet = IP Reservation range start address '{0}' is not in the subnet '{1}'.
RunAsAccountNotFound = RunAs account with name '{0}' does not found in VMM!
SRIOVCannotBeChanged = The SR-IOV setting cannot be changed once the Logical Switch has been created.
BandwidthCannotBeChanged = The MinimumBandwidthMode setting cannot be changed once the Logical Switch has been created.
SecondaryVlanMustBeDifferent = The SecondaryVlanId '{0}' must be different from the VlanId'.
SecondaryVlanNotFound = This Private-VLAN Logical Network requires a SecondaryVlanId value.
StartIPNotInSubnet = The start address '{0}' is not in the subnet '{1}'.
StorageArrayClassificationNotSpecified = Need to specify '{0}' while adding pool to VMM management on provider '{1}'.
StorageArrayNotFound = No storage array found on provider '{0}'!
StorageClassificationNotFound = Storage Classification with name '{0}' was not found.
StorageFileServerNotFound = Storage file server with name '{0}' does not exist!
StorageFileShareNotFound = Storage file share with name '{0}' does not exist on {1}!
StorageLogicalUnitNotFound = Storage logical unit with name '{0}' does not exist on provider {1}!
StorageProviderNotFound = Storage provider with name '{0}' does not exist!
SubnetAlreadyAssigned = The requested Subnet '{0}' is already assigned to a VM Network.
SubnetFormatError = VMSubnet value '{0}' is not formatted correctly - should be in the format: 'SubnetName;SubnetIP/Prefix-VlanId-SecondaryVlanId'.
SubnetNotFound = Subnet on the VM Network '{0}' could not be found.
SubnetUndetermined = Unable to determine the Subnet for this IP Pool.
SubnetVlanMatchNotFound = Unable to find a Subnet/Vlan matching '{0}' on the specified Logical Network / Site.
TeamUplinkAndSRIOVNotAllowed = When SR-IOV is enabled, you cannot use the 'Team' Uplink Mode.
UnSupportedSubnetChanging = Changing the Subnet of a VM Network linked to a VLAN/PVLAN Logical Network is not supported at this time.
UplinkPortNotFound = Unable to find VMM Uplink Port Profile Set named '{0}'.
UplinkPortProfileNotFound = The Uplink Port Profile named '{0}' could not be found.
VIPEndIPNotInSubnet = VIP range end address '{0}' is not in the subnet '{1}'.
VIPIPNotInSubnet = VIP address '{0}' is not in the subnet '{1}'.
VIPStartIPNotInSubnet = VIP range start address '{0}' is not in the subnet '{1}'.
VMMLogicalSwitchRequired = VMMLogicalSwitch parameter is required.
VMNetworkNotFound = The VM Network '{0}' could not be found.
VirtualSwitchExtensionNotFound = A Virtual Switch Extension named '{0}' cannot be found.
VirtualSwitchNotCompatibleWithSRIOV = The Virtual Switch Extension 'Microsoft Windows Filtering Platform' is not compatible with SR-IOV.
VirtualSwitchNotFound = The Hyper-V Virtual Switch named '{0}' could not be found on host '{1}'.
'@

