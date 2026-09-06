package my.MrxSiN.gmailhideads.data;

import android.database.Cursor;
import android.database.CursorWrapper;

/**
 * A cursor that reports the schema of the real result but none of its rows.
 *
 * <p>Returning {@code null} or a fabricated {@link android.database.MatrixCursor}
 * would break Gmail: the caller inspects the column names of the result, and a
 * projection is not always supplied. Wrapping keeps the real column metadata,
 * the real notification URI and the real {@code close()} contract, and only
 * removes the rows.</p>
 */
public final class EmptyCursor extends CursorWrapper {

    public EmptyCursor(Cursor wrapped) {
        super(wrapped);
    }

    @Override
    public int getCount() {
        return 0;
    }

    @Override
    public int getPosition() {
        return -1;
    }

    @Override
    public boolean move(int offset) {
        return false;
    }

    @Override
    public boolean moveToPosition(int position) {
        return false;
    }

    @Override
    public boolean moveToFirst() {
        return false;
    }

    @Override
    public boolean moveToLast() {
        return false;
    }

    @Override
    public boolean moveToNext() {
        return false;
    }

    @Override
    public boolean moveToPrevious() {
        return false;
    }

    @Override
    public boolean isFirst() {
        return false;
    }

    @Override
    public boolean isLast() {
        return false;
    }

    @Override
    public boolean isBeforeFirst() {
        return true;
    }

    @Override
    public boolean isAfterLast() {
        return true;
    }
}
