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
          { data?.venues !== 0 && <>
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
            </>
          }
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
