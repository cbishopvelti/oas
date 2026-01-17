import { Box, TableBody, TableContainer, TableRow, Table, TableCell } from "@mui/material"


export const AnnualLiabilities = ({ data }) => {

  return <Box sx={{ backgroundColor: 'white', p: 2 }}>
    <h3>Liabilities</h3>
    <TableContainer>
      <Table>
        <TableBody>
          <TableRow>
            <TableCell>Credits</TableCell>
            <TableCell>{data?.credits}</TableCell>
          </TableRow>
          <TableRow>
            <TableCell>Total</TableCell>
            <TableCell>{data?.total}</TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </TableContainer>
  </Box>
}
