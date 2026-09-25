import {
  Box, TableContainer, Table,
  TableBody, TableRow, TableCell
} from '@mui/material'

const rows = [
  { key: 'membership', label: 'Membership' },
  { key: 'attendance', label: 'Attendance' },
  { key: 'things', label: 'Things' },
  { key: 'refunds', label: 'Refunds', hideIfZero: true },
  { key: 'other', label: 'Other', hideIfZero: true },
]

export const AnnualCreditUse = ({ data }) => {

  return <Box sx={{ backgroundColor: 'white', p: 2 }}>
    <h3>Credit Use</h3>

    <TableContainer>
      <Table>
        <TableBody>
          {rows
            .filter(({ key, hideIfZero }) => !hideIfZero || data?.[key])
            .map(({ key, label }) => {
              return <TableRow key={key}>
                <TableCell>{label}</TableCell>
                <TableCell>{data?.[key]}</TableCell>
              </TableRow>
            })}
          <TableRow>
            <TableCell>Total</TableCell>
            <TableCell>{data?.total}</TableCell>
          </TableRow>
          {/* Not included in the total: credits moved between members, not used */}
          <TableRow>
            <TableCell>Transfers between members</TableCell>
            <TableCell>{data?.transfers}</TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </TableContainer>
  </Box>
}
