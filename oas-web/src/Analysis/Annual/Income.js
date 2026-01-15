import {
  Box, TableContainer, Table,
  TableBody, TableRow, TableCell
} from '@mui/material'

export const AnnualIncome = ({data}) => {

  console.log("001", data)

  return <Box sx={{backgroundColor: 'white', p: 2}}>
    <h3>Income</h3>

    <TableContainer>
      <Table>
        <TableBody>
          <TableRow>
            <TableCell>Credit</TableCell>
            <TableCell>{data?.credit}</TableCell>
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
