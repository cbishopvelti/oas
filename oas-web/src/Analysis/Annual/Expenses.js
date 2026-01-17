import { Table, TableBody, TableCell, TableContainer, Box, TableRow } from "@mui/material"

export const AnnualExpenses = ({data}) => {



  return <Box sx={{backgroundColor: 'white', p: 2}}>
    <h3>Expenses</h3>
    <TableContainer>
      <Table>
        <TableBody>
          {(data?.tagged || []).map(({ tag_names, amount }, i) => {
            return <TableRow key={i}>
              <TableCell>{(tag_names).join(", ") || "Untagged"}</TableCell>
              <TableCell>{amount}</TableCell>
            </TableRow>
          })}
          <TableRow>
            <TableCell>Total</TableCell>
            <TableCell>{data?.total}</TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </TableContainer>
  </Box>
}
