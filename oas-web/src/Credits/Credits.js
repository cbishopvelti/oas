import { useEffect } from "react";
import { useQuery, gql, useMutation } from "@apollo/client";
import { Link } from 'react-router-dom';
import { get } from 'lodash';
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  Box
} from '@mui/material';
import PaidIcon from '@mui/icons-material/Paid';
import DeleteIcon from '@mui/icons-material/Delete';
import TollIcon from '@mui/icons-material/Toll'
import PeopleIcon from '@mui/icons-material/People';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';
import ShoppingCartIcon from '@mui/icons-material/ShoppingCart';

export const Credits = ({
  member_id,
  refetch: parentRefetch = () => {},
  setChangeNo,
  changeNo = 0
}) => {

  const { data, refetch } = useQuery(gql`
    query ($member_id: Int) {
      credits(member_id: $member_id) {
        id,
        expires_on,
        who_member_id,
        amount,
        when,
        what,
        after_amount,
        thing_id,
        transaction {
          id
        }
        debit {
          id,
          who_member_id
        }
        credit {
          id,
          who_member_id
        }
        membership {
          membership_period_id
        },
        attendance {
          training_id
        }
      }
    }
  `, {
    variables: {
      ...(member_id ? {member_id: member_id} : {} )
    }
  })

  const [mutate] = useMutation(gql`
    mutation ($id: Int!) {
      delete_credit (id: $id) {
        success
      }
    }
  `)

  useEffect(() => {
    refetch();
  }, [changeNo])

  const credits = get(data, "credits", []);

  const deleteClick = (id) => async() => {
    await mutate({
      variables: {
        id: id
      }
    })
    setChangeNo(changeNo + 1)
  }

  return <div>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>What</TableCell>
            <TableCell>When</TableCell>
            <TableCell>Expires on</TableCell>
            <TableCell>Amount</TableCell>
            <TableCell>Cumulating</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {credits.map((credit, i) => {
            return <TableRow key={i}>
              <TableCell>{credit.id}</TableCell>
              <TableCell>{credit.what}</TableCell>
              <TableCell>{credit.when}</TableCell>
              <TableCell>{credit.expires_on}</TableCell>
              <TableCell>{credit.amount}</TableCell>
              <TableCell sx = {{...(credit.after_amount < 0 ? { color: "red" } : {})}}>{credit.after_amount}</TableCell>
              <TableCell>
                {credit?.thing_id && <IconButton
                  title="Go to thing"
                  component={Link}
                  to={`/thing/${credit?.thing_id}`}
                >
                  <ShoppingCartIcon />
                </IconButton>}
                {credit?.attendance?.training_id &&
                  <IconButton
                    title="Go to training"
                    component={Link}
                    to={`/training/${credit?.attendance?.training_id}`}
                  >
                    <FitnessCenterIcon />
                  </IconButton>
                }
                {credit?.membership?.membership_period_id &&
                  <IconButton
                    title="Go to membership period"
                    component={Link}
                    to={`/membership-period/${credit?.membership?.membership_period_id}/members`}
                  >
                    <PeopleIcon />
                  </IconButton>
                }
                {credit?.transaction?.id &&
                  <IconButton
                    title="Go to transaction"
                    component={Link}
                    to={`/transaction/${credit.transaction.id}`}>
                    <PaidIcon />
                  </IconButton>
                }
                {credit?.credit?.id && <IconButton
                  title="Go to member"
                  component={Link}
                  to={`/member/${credit?.credit?.who_member_id}/credits`}>
                  <TollIcon />
                </IconButton>
                }
                {credit?.debit?.id &&
                  <>
                    <IconButton
                      title="Go to member's credits"
                      component={Link}
                      to={`/member/${credit?.debit?.who_member_id}/credits`}>
                        <TollIcon />
                    </IconButton>
                    <IconButton
                      title="Delete credit"
                      onClick={deleteClick(credit.id)}>
                      <DeleteIcon sx={{color: "red"}} />
                    </IconButton>
                  </>
                }
              </TableCell>
            </TableRow>
          })}
        </TableBody>
      </Table>
    </TableContainer>
  </div>
}
