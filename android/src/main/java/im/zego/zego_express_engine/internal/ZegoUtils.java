package im.zego.zego_express_engine.internal;

import java.util.ArrayList;
import java.util.Iterator;

public class ZegoUtils {
    /* Utils */

    public static boolean boolValue(Boolean number) {
        return number != null && number;
    }

    public static int intValue(Number number) {
        return number != null ? number.intValue() : 0;
    }

    public static long longValue(Number number) {
        return number != null ? number.longValue() : 0;
    }

    public static float floatValue(Number number) {
        return number != null ? number.floatValue() : .0f;
    }

    public static double doubleValue(Number number) {
        return number != null ? number.doubleValue() : .0f;
    }

    public static int[] intArrayValue(ArrayList<Integer> integerArrayList) {
        int[] ret = new int[integerArrayList.size()];
        Iterator<Integer> iterator = integerArrayList.iterator();
        for (int i = 0; i < ret.length; i++) {
            ret[i] = iterator.next();
        }
        return ret;
    }

    public static float[] floatArrayValueFromDoubleArray(ArrayList<Double> floatArrayList) {
        float[] ret = new float[floatArrayList.size()];
        Iterator<Double> iterator = floatArrayList.iterator();
        for (int i = 0; i < ret.length; i++) {
            ret[i] = iterator.next().floatValue();
        }
        return ret;
    }
}