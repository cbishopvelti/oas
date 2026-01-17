import {
  Box, TableContainer, Table,
  TableBody, TableRow, TableCell
} from '@mui/material'

export const AnnualBalance = ({ balance }) => {
  return <Box sx={{backgroundColor: 'white', p: 2}}>
    <h3>Balance</h3>

    <h3>{balance}</h3>
  </Box>

}
