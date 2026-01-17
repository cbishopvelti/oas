import {
  Box, TableBody, TableCell, TableContainer,
  Table, TableRow
} from "@mui/material"

export const AnnualReceivables = ({data}) => {

  // analysis.ex .outstanding_attendance
  // schema_analysis .get_global_debt

  return <Box sx={{ backgroundColor: "white", p: 2 }}>
    <h3>Recievables</h3>

    <TableContainer>
      <Table>
        <TableBody>
          <TableRow>
            <TableCell>Credits</TableCell>
            <TableCell>{ data?.credits }</TableCell>
          </TableRow>
          <TableRow>
            <TableCell>Tokens</TableCell>
            <TableCell>{data?.tokens}</TableCell>
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
