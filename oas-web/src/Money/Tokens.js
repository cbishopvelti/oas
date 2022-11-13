import { useQuery, gql, useMutation } from "@apollo/client";
import { get } from 'lodash'
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
import { Link } from 'react-router-dom'
import moment from 'moment';
import { useEffect } from "react";
import { TransactionAddToken } from './TransactionToken';
import DeleteIcon from '@mui/icons-material/Delete';
import { TransferToken } from "./TransferToken";
import PaidIcon from '@mui/icons-material/Paid';



const isUsable = (token) => {
  if (moment(token.expires_on).isBefore(moment())) {
    return false;
  }
  if(token.used_on) {
    return false
  }
  return true;
}

export const Tokens = ({
  transaction,
  member_id,
  refetch: parentRefetch = () => {}
}) => {
  const transaction_id = transaction?.id

  if (transaction && member_id) {
    throw "can not have both member_id and transaction set";
  }

  let memberQuery = '';
  if (transaction) {
    memberQuery = `member {
      name
    }`
  }

  const { data, refetch } = useQuery(gql`
    query ($member_id: Int, $transaction_id: Int) {
      tokens(member_id: $member_id, transaction_id: $transaction_id) {
        id,
        expires_on,
        used_on,
        member_id,
        value,
        transaction {
          id
        }
        ${memberQuery}
      }
    }
  `, {
    variables: {
      ...(member_id ? {member_id: member_id} : {} ),
      ...(transaction_id ? {transaction_id: transaction_id} : {} )
    }
  })
  const tokens = get(data, 'tokens', []);
  useEffect(() => {
    refetch()
    parentRefetch();
  }, [member_id, transaction_id])


  const [deleteMutation] = useMutation(gql`
    mutation ($token_id: Int!){
      delete_tokens(token_id: $token_id) {
        success
      }
    }
  `)
  const deleteToken = (token_id) => async () => {
    await deleteMutation({
      variables: {
        token_id: parseInt(token_id)
      }
    });
    refetch();
    parentRefetch();
  }

  return <div>
    {transaction_id && <TransactionAddToken
      transaction_id={transaction_id}
      member_id={transaction.who_member_id}
      refetch={() => {
        refetch();
        parentRefetch()
      }} />}
    <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Id</TableCell>
              {memberQuery && <TableCell>Owner</TableCell>}
              <TableCell>Expires on</TableCell>
              <TableCell>Used on</TableCell>
              <TableCell>Value</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {
              tokens.map((token) => {
                const sx = {
                  ...(!isUsable(token) ? {
                    color: "gray",
                    textDecoration: "line-through"
                  }: {}),
                  // color: "pink"
                }
                return (<TableRow key={token.id}>
                  <TableCell sx={sx}>{token.id}</TableCell>
                  {memberQuery && <TableCell sx={sx}>{token.member.name}</TableCell>}
                  <TableCell sx={sx}>{token.expires_on}</TableCell>
                  <TableCell sx={sx}>{token.used_on}</TableCell>
                  <TableCell sx={sx}>{token.value}</TableCell>
                  <TableCell>
                    {isUsable(token) && <TransferToken token={token} refetch={refetch} />}
                    {!transaction && get(token, 'transaction.id') &&
                      <IconButton component={Link} title={`Go to this token's transaction`} to={`/transaction/${token.transaction.id}`}>
                        <PaidIcon />
                      </IconButton>
                    }
                    {!token.used_on && <IconButton title={`Delete this token`} onClick={deleteToken(token.id)}>
                      <DeleteIcon sx={{color: 'red'}} />
                    </IconButton>}
                    
                  </TableCell>
                </TableRow>)
              })
            }
          </TableBody>
        </Table>
      </TableContainer>
    </div>

}