// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;
import MemPortal::*;

import TinyTestTypes::*;

// generated by tool
import Tiny3Indication::*;
import Tiny3Request::*;

// defined by user
import TinyTest::*;

typedef enum {Tiny3Indication, Tiny3Request} IfcNames deriving (Eq,Bits);

module mkConnectalTop(StdConnectalTop#(PhysAddrWidth));

   // instantiate user portals
   Tiny3IndicationProxy tiny3IndicationProxy <- mkTiny3IndicationProxy(Tiny3Indication);
   Tiny3Request tiny3Request <- mkTiny3Request(tiny3IndicationProxy.ifc);
   Tiny3RequestWrapper tiny3RequestWrapper <- mkTiny3RequestWrapper(Tiny3Request,tiny3Request);
   
   Vector#(2,StdPortal) portals;
   portals[0] = tiny3RequestWrapper.portalIfc;
   portals[1] = tiny3IndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;

endmodule : mkConnectalTop


