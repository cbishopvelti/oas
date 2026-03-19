import { gql, useQuery } from "@apollo/client"
import { Box, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, IconButton } from "@mui/material"
import { useParams, useOutletContext, Link } from "react-router-dom";
import { get } from "lodash";
import { useEffect } from "react";
import PaidIcon from '@mui/icons-material/Paid';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';

export const VenueAccount = () => {
  const { setTitle } = useOutletContext();

  let { training_where_id } = useParams();
  if (training_where_id) {
    training_where_id = parseInt(training_where_id);
  }

  const { data, refetch } = useQuery(gql`
    query($training_where_id: Int!) {
      training_where(id: $training_where_id){
        name,
        account_liability
      }
      training_where_account_liability(id: $training_where_id) {
        what,
        when,
        amount,
        acc_amount,
        transaction_id,
        training_id
      }
    }
  `, {
    variables: {
      training_where_id: training_where_id
    }
  })

  useEffect(() => {
    refetch()
  }, [])

  useEffect(() => {
    setTitle(`Liability to ${get(data, 'training_where.name', '')}: ${get(data, 'training_where.account_liability', '')}`);
  }, [data])

  return <Box sx={{ display: 'flex', gap: 2, m: 2, alignItems: 'center' }}>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>What</TableCell>
            <TableCell>When</TableCell>
            <TableCell>Amount</TableCell>
            <TableCell>Cumulating</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {
            get(data, "training_where_account_liability", []).map((liability, i) => {
              return <TableRow key={i}>
                <TableCell>{liability.what}</TableCell>
                <TableCell>{liability.when}</TableCell>
                <TableCell>{liability.amount}</TableCell>
                <TableCell>{liability.acc_amount}</TableCell>
                <TableCell>
                  {liability.transaction_id && <IconButton
                    title="Go to transaction"
                    component={Link}
                    to={`/transaction/${liability.transaction_id}`}>
                    <PaidIcon />
                  </IconButton>}
                  {liability.training_id && <IconButton
                    title="Go to training"
                    component={Link}
                    to={`/training/${liability.training_id}`}>
                      <FitnessCenterIcon />
                  </IconButton>}
                </TableCell>
              </TableRow>
            })
          }
        </TableBody>
      </Table>
    </TableContainer>
  </Box>
}
