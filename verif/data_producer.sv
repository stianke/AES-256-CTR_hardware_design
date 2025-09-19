module data_producer #(
    parameter DATA_WIDTH = 128,
    parameter FILE_NAME  = "../../../../../verif/generated_test_data/plaintext.txt"
)(
    input  logic                  clk,
    input  logic                  rst,
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready
);

    integer fd;
    bit file_open = 1;
    logic [DATA_WIDTH-1:0] word;

    initial begin
        fd = $fopen(FILE_NAME, "r");
        if (fd == 0) $fatal(1, "Failed to open input file: %s", FILE_NAME);
        $fscanf(fd, "%h\n", word);
        // Close file when done
        fork
            begin
                wait ($feof(fd));
                $fclose(fd);
            end
        join_none
    end

    always_ff @(posedge clk) begin
        m_axis_tvalid <= m_axis_tvalid;
        m_axis_tdata  <= m_axis_tdata;
        m_axis_tlast <= m_axis_tlast;
        
        if (rst) begin
            m_axis_tvalid <= 1;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= word;
        end else if (m_axis_tready && m_axis_tvalid) begin
            m_axis_tvalid <= 0;
            m_axis_tdata  <= '0;
            m_axis_tlast <= 0;
            if (file_open == 1) begin
                if ($fscanf(fd, "%h\n", word) == 1) begin
                    m_axis_tdata  <= word;
                    m_axis_tvalid <= 1;
                    m_axis_tlast  <= $feof(fd); // last word if file ends
                    if ($feof(fd)) begin
                        $fclose(fd);
                        file_open <= 0;
                    end
                end
            end
        end
    end

endmodule
