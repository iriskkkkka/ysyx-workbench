#include <nvboard.h>
#include <Vtop.h>

static TOP_NAME dut;

void nvboard_bind_all_pins(TOP_NAME* top);

void single_cycle(){
  dut.clk=0; 
  dut.eval();
  dut.clk=1; 
  dut.eval();
}

void ares(int n){
  dut.ares=1;
  int i=0;
  while (i<n){
    single_cycle();
    i++;
  }
  dut.ares=0;
}

int main() {
  nvboard_bind_all_pins(&dut);
  nvboard_init();

  ares(10);

  while(1) {
    nvboard_update();
    single_cycle();
  }
}
