module data_producer #(
    parameter DATA_WIDTH = 128
)(
    input  logic                  clk,
    input  logic                  rst,
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready,
    input  integer                test_number
);

    integer fd;
    integer next_test_number = 0;
    bit file_open = 0;
    logic [DATA_WIDTH-1:0] word;
    string plaintext_filename;
    
    always_ff @(posedge clk) begin
        m_axis_tvalid <= m_axis_tvalid;
        m_axis_tdata  <= m_axis_tdata;
        m_axis_tlast <= m_axis_tlast;
        
        if (rst) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= '0;
        end else if (file_open == 0) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= '0;
            
            if (test_number == next_test_number) begin // Wait until caller increments to next test
                plaintext_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_plaintext.txt", test_number);
                fd = $fopen(plaintext_filename, "r");
                if (fd == 0) $fatal(1, "Failed to open expected plaintext file: %s", plaintext_filename);
                //$display("Opened file %s: %0d", plaintext_filename, fd);
                $fscanf(fd, "%h\n", word);
                m_axis_tdata <= word;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= $feof(fd);
                
                file_open <= 1;
                next_test_number <= test_number + 1;
            end
        end else if (m_axis_tready && m_axis_tvalid) begin
            m_axis_tvalid <= 0;
            m_axis_tdata  <= '0;
            m_axis_tlast <= 0;
            if ($fscanf(fd, "%h\n", word) == 1) begin
                m_axis_tdata  <= word;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= $feof(fd); // last word if file ends
                if ($feof(fd)) begin
                    $fclose(fd);
                    file_open <= 0;
                    $display("Closed plaintext file");
                end
            end
        end
    end

endmodule
