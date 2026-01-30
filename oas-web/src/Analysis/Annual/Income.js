import {
  Box, TableContainer, Table,
  TableBody, TableRow, TableCell
} from '@mui/material'

export const AnnualIncome = ({data}) => {

  return <Box sx={{backgroundColor: 'white', p: 2}}>
    <h3>Income</h3>

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
