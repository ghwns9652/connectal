// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import ConnectalMemory::*;
import MemTypes::*;
import MemServer::*;
import MMU::*;
import Leds::*;

// generated by tool
import MemreadRequest::*;
import DmaDebugRequest::*;
import MMUConfigRequest::*;
import MemreadIndication::*;
import DmaDebugIndication::*;
import MMUConfigIndication::*;

// defined by user
import Memread::*;

typedef enum {HostDmaDebugIndication, HostDmaDebugRequest, HostMMUConfigRequest, HostMMUConfigIndication, MemreadIndication, MemreadRequest} IfcNames deriving (Eq,Bits);

module mkConnectalTop(ConnectalTop#(PhysAddrWidth,128,Empty,1));

   MemreadIndicationProxy memreadIndicationProxy <- mkMemreadIndicationProxy(MemreadIndication);
   Memread memread <- mkMemread(memreadIndicationProxy.ifc);
   MemreadRequestWrapper memreadRequestWrapper <- mkMemreadRequestWrapper(MemreadRequest,memread.request);

   Vector#(1, MemReadClient#(128)) readClients = cons(memread.dmaClient, nil);
   MMUConfigIndicationProxy hostMMUConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMUConfigIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMUConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMUConfigRequest, hostMMU.request);

   DmaDebugIndicationProxy hostDmaDebugIndicationProxy <- mkDmaDebugIndicationProxy(HostDmaDebugIndication);
   MemServer#(PhysAddrWidth,128,1) dma <- mkMemServerR(hostDmaDebugIndicationProxy.ifc, readClients, cons(hostMMU,nil));
   DmaDebugRequestWrapper hostDmaDebugRequestWrapper <- mkDmaDebugRequestWrapper(HostDmaDebugRequest, dma.request);

   Vector#(6,StdPortal) portals;
   portals[0] = memreadRequestWrapper.portalIfc;
   portals[1] = memreadIndicationProxy.portalIfc; 
   portals[2] = hostDmaDebugRequestWrapper.portalIfc;
   portals[3] = hostDmaDebugIndicationProxy.portalIfc; 
   portals[4] = hostMMUConfigRequestWrapper.portalIfc;
   portals[5] = hostMMUConfigIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
   interface leds = default_leds;
      
endmodule : mkConnectalTop
