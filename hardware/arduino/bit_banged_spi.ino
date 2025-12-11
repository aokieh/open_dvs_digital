//---------------------------------------------------------------------------------

#include "input_array.h"       //location of row_mem

#define MOSI_PIN 11  // Pin for SPI MOSI (Master Out Slave In)
#define MISO_PIN 9   // Pin for SPI MISO (Master In Slave Out)
#define SS_PIN 10    // Pin for SPI Slave Select (SS)
#define SCK_PIN 8   // Pin for SPI Clock (SCK)
#define NUM_BYTES 4

bool falling_edge_detected = false; // Flags to indicate SCK edge
bool rising_edge_detected = false;
bool write_to_fpga = true;          // Flags to indicate communication mode
bool read_from_fpga = false;

bool opcode_sent = false;           // Flags for state of data transmission
bool addr_sent = false;
bool data_sent = false;

static int byte_counter = 0;  // Keeps track of the current byte being sent
static int bit_count_write = 0;
static int bit_count_read = 0;  // Track number of bits transmitted

uint8_t data_read = 0b00000000;

void setup() {
  pinMode(MOSI_PIN, OUTPUT);  // Set MOSI pin as output
  pinMode(SS_PIN, OUTPUT);    // Set SS pin as output
  pinMode(SCK_PIN, OUTPUT);   // Set clock pin as output
  pinMode(MISO_PIN, INPUT);   // Set MISO pin as input
  
  Serial.begin(9600); // Start serial communication at 9600 bits per second

  // Stop Timer1
  TCCR1A = 0;
  TCCR1B = 0;

  // Use Timer1 in CTC mode (Clear Timer on Compare Match)
  TCCR1B |= (1 << WGM12);

  // Set prescaler to 64 for 30Hz refresh rate (33.33ms interval)
  TCCR1B |= (1 << CS11) | (1 << CS10);  // Prescaler 64

  // Set OCR1A for 33.33ms interval (30Hz refresh rate)
  OCR1A = 8325;  // Corrected OCR1A value for 33.33ms period (30Hz)

  // Enable Timer1 compare match interrupt
  TIMSK1 |= (1 << OCIE1A);

  // Enable global interrupts
  sei();
}

ISR(TIMER1_COMPA_vect) {
  // Toggle the clock every 1ms to generate a 1kHz clock signal
  digitalWrite(SCK_PIN, !digitalRead(SCK_PIN));

  // Read the clock pin state for falling edge detection
  static bool lastClockState = HIGH;  // Last state of the clock
  bool currentClockState = digitalRead(SCK_PIN);

  // Check for falling edge (transition from HIGH to LOW)
  if (lastClockState == HIGH && currentClockState == LOW) {
    falling_edge_detected = true;  // Set the flag on falling edge
  }
  if(lastClockState == LOW && currentClockState == HIGH){
    rising_edge_detected = true;
  }
  lastClockState = currentClockState;  // Update last state for next comparison
}

void sendData() {
  // static int byte_counter = 0;  // Keeps track of the current byte being sent
  uint8_t opcode = 0b00000100;  // Static opcode for the transaction
  uint8_t addr = byte_counter;  // Example address
  uint8_t data = currentData(byte_counter);  // Get data from memory

  // static int bit_counter = 0;  // Track number of bits transmitted

  if (byte_counter == 0 && write_to_fpga) {
    Serial.println("\n\n------  Data Writing Begin  ------");
    // byte_counter = 0;  // Reset to start over (or change as needed)
  }else if (byte_counter == 0 && read_from_fpga){
    Serial.println("\n\n------  Data Reading Begin  ------");
  }

  //ensures that all data has been written/read
  if (byte_counter >= NUM_BYTES  && !write_to_fpga && !read_from_fpga){
    Serial.println("\n\nData Writing Complete\n\n");
    return; //TODO : forcefully leaving the program, determine cause
  }
  
  // Assert Slave Select (SS) to begin transmission
  digitalWrite(SS_PIN, LOW);  

  // Send data bit by bit only on falling edges to FPGA
  // if (falling_edge_detected && byte_counter < NUM_BYTES) {//TODO remove this 
  if (falling_edge_detected && write_to_fpga) {
    if (bit_count_write < 8) {
      // Send opcode bits
      digitalWrite(MOSI_PIN, bitRead(opcode, 7 - bit_count_write));  // MSB first
    } else if (bit_count_write < 16) {
      // Send address bits
      digitalWrite(MOSI_PIN, bitRead(addr, 7 - (bit_count_write - 8)));  // MSB first
    } else {
      // Send data bits
      digitalWrite(MOSI_PIN, bitRead(data, 7 - (bit_count_write - 16)));  // MSB first
    }
    bit_count_write++;              // Increment bit counter
    falling_edge_detected = false;  // Reset the flag until the next falling edge

    if (bit_count_write == 25) {  //an extra rising edge is needed, new data doesn't get padded :)
      // Deassert Slave Select (SS) after sending all 24 bits
      digitalWrite(SS_PIN, HIGH);
    
      // Move to the next byte
      byte_counter++;

      if (byte_counter >= NUM_BYTES && write_to_fpga) { //after sending every byte of data, post-increment
        digitalWrite(SS_PIN, HIGH);
        Serial.println("\n------  Data Writing complete  ------");
        Serial.println("\n\n------  Data Read Begin  ------");
        byte_counter = 0;             // Reset to start over address counter
                                    // transition from writing to reading data
        write_to_fpga = false;
        read_from_fpga = true;
      }
      // Reset bit counter for the next byte
      bit_count_write = 0;
    }
  }


    // if ((falling_edge_detected || rising_edge_detected) && read_from_fpga && (bit_count_read < 16) ) {//reading from FPGA
  if (falling_edge_detected && read_from_fpga && (bit_count_read < 25)) {//reading from FPGA
    opcode = 0b00000000; //manually read from FPGA
    if (bit_count_read < 8) {
      digitalWrite(MOSI_PIN, bitRead(opcode, 7 - bit_count_read));  // MSB first
      falling_edge_detected = false;  // Reset the flag until the next falling edge
    } else if (bit_count_read < 16) {
      // Send address bits
      digitalWrite(MOSI_PIN, bitRead(addr, 7 - (bit_count_read - 8)));  // MSB first
      falling_edge_detected = false;  // Reset the flag until the next falling edge
    } else if (rising_edge_detected && read_from_fpga && (bit_count_read >= 16 && bit_count_read < 24)){
      data = (data << 1) | digitalRead(MISO_PIN);
      // bit_count_read++;  // Increment bit counter
      rising_edge_detected = false;  // Reset the flag until the next falling edge
    } 
    bit_count_read++;
  }
  // Check if all 24 bits (8 opcode + 8 address + 8 data) have been sent
  if (bit_count_read == 25) {  //an extra rising edge is needed, new data doesn't get padded :)
    // Deassert Slave Select (SS) after sending all 24 bits
    digitalWrite(SS_PIN, HIGH);
    
    // Move to the next byte
    byte_counter++;
    bit_count_read = 0;

    Serial.print("\nAddr[");
    Serial.print(addr);
    Serial.print("]: ");
    Serial.print(data, HEX);


    if (byte_counter >= NUM_BYTES && read_from_fpga) {
      Serial.println("\n\n------  Data Writing Begin  ------");
      read_from_fpga = false;

    }

      // Reset bit counter for the next byte
    bit_count_write = 0;
    bit_count_read = 0;
    }
    Serial.print("\nAddr: [");
    Serial.print(addr);
    Serial.print(" | ");
    Serial.print(bit_count_write);
    Serial.print("]    ");

    Serial.print("Data: [");
    Serial.print(data);
    Serial.print("]    \n");
    delay(10);  // Add delay before the next byte transmission
}

uint8_t currentData(int byte_counter) {
    return row_mem[byte_counter / 4][byte_counter % 4];  // Get data from memory
}





void loop() {
  // The main loop is empty since the SPI communication is handled in ISR
  // The data is transmitted automatically via the interrupt on the falling edge

  // Serial.println("Beginning execution\n");

  sendData();
  delay(10);  // Add delay before the next byte transmission


}