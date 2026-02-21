import { Box, TableBody, TableContainer, TableRow, Table, TableCell } from "@mui/material"


export const AnnualLiabilities = ({ data }) => {

  return <Box sx={{ backgroundColor: 'white', p: 2 }}>
    <h3>Liabilities</h3>
    <TableContainer>
      <Table>
        <TableBody>
          {(data?.venues_tagged || []).map(({ tag_names, amount }, i) => {
            return <TableRow key={i}>
              <TableCell>{(tag_names).join(", ") || "Other Venues"}</TableCell>
              <TableCell>{amount}</TableCell>
            </TableRow>
          })}
          <TableRow>
            <TableCell>Venues</TableCell>
            <TableCell>{data?.venues}</TableCell>
          </TableRow>
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
